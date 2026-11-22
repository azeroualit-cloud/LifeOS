import XCTest
@testable import LifeOSProbe

@MainActor private final class DiaryWriter: NativeNutritionWriting {
    var writes: [NativeNutritionEntry] = []
    var deletions: [UUID] = []
    func authorize(includeFibre: Bool) async throws {}
    func write(_ entry: NativeNutritionEntry) async throws { writes.append(entry) }
    func delete(_ entry: NativeNutritionEntry) async throws { deletions.append(entry.id) }
}

/// FOOD-DIARY-SERVER-2026-11-22: the diary is shared through the server (phone and PC);
/// the most recent change wins; deletions travel; weight is never sent.
@MainActor final class NativeFoodDiarySyncTests: XCTestCase {
    /// Minimal in-memory copy of the diary methods in backend/bloom-foods/bloomfoods.mjs.
    final class Server {
        var offers = true
        var rows: [String: Record] = [:]
        var calls: [String] = []
        func handle(_ method: String, _ args: [JSONValue]) throws -> JSONValue {
            calls.append(method)
            guard offers else { throw NativeRequestRejected(status: 400, message: "Operazione non disponibile.") }
            switch method {
            case "listFoodDiary":
                let since = args.first?.number ?? 0
                return .object(["version": .int(1), "entries": .array(rows.values.filter { $0.amount("modified") > since }.map(JSONValue.object))])
            case "importFoodDiary":
                for value in args[0].array { _ = save(value.object) }
                return .object([:])
            case "saveFoodDiaryEntry":
                return .object(save(args[0].object))
            case "deleteFoodDiaryEntry":
                let id = args[0].string
                guard var row = rows[id], row.amount("modified") <= args[1].number else { return .object(["deleted": .bool(false)]) }
                row["deleted"] = .bool(true); row["modified"] = args[1]; rows[id] = row
                return .object(["deleted": .bool(true)])
            default: throw NativeRequestRejected(status: 400, message: "Operazione non disponibile.")
            }
        }
        private func save(_ row: Record) -> Record {
            if let old = rows[row.text("id")], old.amount("modified") > row.amount("modified") { return ["saved": .bool(false), "entry": .object(old)] }
            var stored = row; stored["deleted"] = .bool(false); rows[row.text("id")] = stored
            return ["saved": .bool(true), "entry": .object(stored)]
        }
    }

    private func setup() -> (NativeFoodDiarySync, NativeNutritionStore, DiaryWriter, Server, NativeFoodDiarySync.Reader) {
        let defaults = UserDefaults(suiteName: "diary-" + UUID().uuidString)!
        let writer = DiaryWriter()
        let store = NativeNutritionStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), writer: writer)
        let sync = NativeFoodDiarySync(defaults: defaults, store: store)
        let server = Server()
        sync.connect {}
        return (sync, store, writer, server, { method, args in try server.handle(method, args) })
    }
    private func meal(_ name: String = "Skyr", grams: Decimal = 150) -> NativeNutritionEntry {
        var e = NativeNutritionEntry(id: UUID(), revision: 0, date: Date(timeIntervalSince1970: 1_795_300_000), protein: 16.5, carbohydrate: 5.9, fat: 0.3, confirmed: false)
        e.foodName = name; e.portionGrams = grams; e.labelCalories = 95
        e.nutrientValues = ["calcium": .init(amount: 180, estimateSource: nil)]
        return e
    }

    func testRowCarriesReadableFieldsAndTheCompleteAppEntry() throws {
        var entry = meal(); entry.modifiedAt = Date(timeIntervalSince1970: 1_795_300_100)
        let row = try NativeFoodDiarySync.row(entry)
        XCTAssertEqual(row.text("name"), "Skyr")
        XCTAssertEqual(row.amount("grams"), 150)
        XCTAssertEqual(row.amount("kcal"), 95)
        XCTAssertEqual(row.amount("modified"), 1_795_300_100_000)
        XCTAssertEqual(row.record("app").record("nutrientValues").record("calcium").amount("amount"), 180)
        let back = try XCTUnwrap(NativeFoodDiarySync.entry(row))
        XCTAssertEqual(back.id, entry.id)
        XCTAssertEqual(back.nutrientValues?["calcium"]?.amount, 180, "micronutrients survive the round trip")
        XCTAssertEqual(back.date.timeIntervalSince1970, entry.date.timeIntervalSince1970, accuracy: 0.01)
    }

    func testSiteEditOverridesReadableFieldsAndSiteMealNeedsNoAppPart() throws {
        var row = try NativeFoodDiarySync.row(meal())
        row["grams"] = .number(200); row["protein"] = .number(22); row["kcal"] = .number(127); row["name"] = .string("Skyr bianco")
        let edited = try XCTUnwrap(NativeFoodDiarySync.entry(row))
        XCTAssertEqual(edited.portionGrams, 200); XCTAssertEqual(edited.protein, 22); XCTAssertEqual(edited.calories, 127); XCTAssertEqual(edited.foodName, "Skyr bianco")
        let site: Record = ["id": .string(UUID().uuidString), "at": .string("2026-11-22T12:30:00Z"), "name": .string("Pasta"), "grams": .number(90), "kcal": .number(320), "protein": .number(11), "carbs": .number(65), "fat": .number(1.5), "revision": .int(1), "modified": .number(5000), "app": .object([:])]
        let created = try XCTUnwrap(NativeFoodDiarySync.entry(site))
        XCTAssertEqual(created.foodName, "Pasta"); XCTAssertEqual(created.carbohydrate, 65); XCTAssertEqual(created.calories, 320)
    }

    func testFirstSyncSendsHistoryOnceThenLocalChangesTravel() async throws {
        let (sync, store, _, server, read) = setup()
        let first = meal()
        let saved = await store.save(first)
        XCTAssertTrue(saved)
        try await sync.sync(read)
        XCTAssertEqual(server.rows.count, 1, "history sent once")
        XCTAssertTrue(server.calls.contains("importFoodDiary"))
        var second = meal("Mela", grams: 120); second.labelCalories = 62
        let savedSecond = await store.save(second)
        XCTAssertTrue(savedSecond)
        XCTAssertEqual(sync.pending.count, 1, "the local save is queued")
        try await sync.sync(read)
        XCTAssertEqual(server.rows.count, 2)
        XCTAssertTrue(sync.pending.isEmpty)
        let deleted = await store.delete(second.id)
        XCTAssertTrue(deleted)
        try await sync.sync(read)
        XCTAssertEqual(server.rows[second.id.uuidString]?.flag("deleted"), true, "the deletion reaches the server")
    }

    func testEditsAndDeletionsFromThePcReachAppleHealth() async throws {
        let (sync, store, writer, server, read) = setup()
        let entry = meal()
        _ = await store.save(entry)
        try await sync.sync(read)
        let revision = try XCTUnwrap(store.entries.first?.revision)
        var row = try XCTUnwrap(server.rows[entry.id.uuidString])
        row["grams"] = .number(200); row["kcal"] = .number(127); row["modified"] = .number(row.amount("modified") + 60_000)
        server.rows[entry.id.uuidString] = row
        writer.writes = []
        try await sync.sync(read)
        let updated = try XCTUnwrap(store.entries.first { $0.id == entry.id })
        XCTAssertEqual(updated.portionGrams, 200)
        XCTAssertGreaterThan(updated.revision, revision, "a higher revision replaces the Apple Health samples")
        XCTAssertEqual(writer.writes.count, 1)
        XCTAssertTrue(sync.pending.isEmpty, "applying the server copy is not sent back")
        row["deleted"] = .bool(true); row["modified"] = .number(row.amount("modified") + 60_000)
        server.rows[entry.id.uuidString] = row
        try await sync.sync(read)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(writer.deletions, [entry.id])
    }

    func testOlderServerCopyNeverOverwritesALocalChangeAndOldWorkerChangesNothing() async throws {
        let (sync, store, writer, server, read) = setup()
        let entry = meal()
        _ = await store.save(entry)
        try await sync.sync(read)
        var stale = try XCTUnwrap(server.rows[entry.id.uuidString])
        stale["grams"] = .number(10); stale["modified"] = .number(1)
        server.rows[entry.id.uuidString] = stale
        writer.writes = []
        let defaults = UserDefaults.standard
        _ = defaults
        try await sync.sync(read)
        XCTAssertEqual(store.entries.first?.portionGrams, 150)
        XCTAssertTrue(writer.writes.isEmpty)

        let (oldSync, oldStore, _, oldServer, oldRead) = setup()
        oldServer.offers = false
        _ = await oldStore.save(meal())
        try await oldSync.sync(oldRead)
        XCTAssertEqual(oldStore.entries.count, 1)
        XCTAssertEqual(oldSync.pending.count, 1, "kept until a Worker with the diary answers")
    }
}
