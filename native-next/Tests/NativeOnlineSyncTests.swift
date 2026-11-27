import XCTest
@testable import LifeOSProbe

/// BUILD93-REQUEST-2026-11-21: Bloom and personal foods come from the server, the device
/// sends its copy once, and nothing changes when the server does not offer the methods.
@MainActor final class NativeOnlineSyncTests: XCTestCase {
    /// Minimal in-memory version of backend/bloom-foods/bloomfoods.mjs.
    final class FakeServer {
        var offers = true
        var calls: [String] = []
        var foods: [String: Record] = [:]
        var items: [String: Record] = [:]
        var collections: [String: Record] = [:]
        var clock = 2_000_000_000.0
        var delta = false // FOOD-SYNC-DELTA: offers listFoodChanges
        var tick = 0
        var changedAt: [String: String] = [:]
        var tombstones: [String: String] = [:]
        func stamp() -> String { tick += 1; return "2026-11-25T00:00:00." + String(format: "%06d", tick) }
        func handle(_ method: String, _ args: [JSONValue]) throws -> JSONValue {
            calls.append(method)
            guard offers else { throw NativeRequestRejected(status: 400, message: "Operazione non disponibile.") }
            switch method {
            case "importFoods", "saveFood":
                let list = method == "saveFood" ? [args[0]] : args[0].array
                for value in list {
                    let a = value.object
                    var app = a; for k in ["id", "name", "brand", "family", "measurementBasis", "calories", "protein", "carbohydrate", "fat", "fibre", "nutritionNotDeclared", "nutrientValues", "aliases", "dataNote"] { app.removeValue(forKey: k) }
                    changedAt[a.text("id")] = stamp(); tombstones.removeValue(forKey: a.text("id"))
                    foods[a.text("id")] = ["id": a["id"]!, "name": a["name"]!, "brand": a["brand"] ?? .string(""), "family": a["family"]!, "basis": .string("g"), "kcal": a["calories"]!, "protein": a["protein"]!, "carbs": a["carbohydrate"]!, "fat": a["fat"]!, "fibre": a["fibre"] ?? .null, "micro": .object([:]), "aliases": .array([]), "note": .string(""), "app": .object(app)]
                }
                return .object(["imported": .int(list.count)])
            case "deleteFood": siteDeleteFood(args[0].string); return .object(["ok": .bool(true)])
            case "listFoodChanges" where delta:
                let since = args.first?.string ?? ""
                let rows = foods.filter { since.isEmpty || (changedAt[$0.key] ?? "") > since }.map(\.value)
                let gone = since.isEmpty ? [] : tombstones.filter { $0.value > since }.map(\.key)
                let last = ([since] + changedAt.values + tombstones.values).max() ?? ""
                return .object(["full": .bool(since.isEmpty), "foods": .array(rows.map(JSONValue.object)), "deleted": .array(gone.map(JSONValue.string)), "stamp": .string(last)])
            case "listFoods": return .object(["foods": .array(foods.values.map(JSONValue.object))])
            case "importBloom":
                let p = args[0].object
                for c in p.records("collections") where collections[c.text("id")] == nil { collections[c.text("id")] = ["id": c["id"]!, "name": c["name"]!, "doc": .object([:])] }
                for i in p.records("items") {
                    XCTAssertNil(i["data"], "attachment bytes never leave the device")
                    items[i.text("id")] = row(i)
                }
                return .object(["added": .int(p.records("items").count)])
            case "saveBloomItem":
                let i = args[0].object
                if let expected = i["expectModifiedAt"]?.number, let current = items[i.text("id")], current.amount("modifiedAt") > expected {
                    return .object(["id": i["id"]!, "conflict": .bool(true), "current": .object(current)])
                }
                clock += 10
                var r = row(i); r["modifiedAt"] = .number(clock); items[i.text("id")] = r
                return .object(["id": i["id"]!, "modifiedAt": .number(clock)])
            case "trashBloomItem": return .object(["ok": .bool(true)])
            case "deleteBloomItem": items.removeValue(forKey: args[0].string); return .object(["ok": .bool(true)])
            case "saveBloomCollection": let c = args[0].object; collections[c.text("id")] = ["id": c["id"]!, "name": c["name"]!, "doc": .object([:])]; return .object(["id": c["id"]!])
            case "deleteBloomCollection": collections.removeValue(forKey: args[0].string); return .object(["ok": .bool(true)])
            case "getBloom": return .object(["collections": .array(collections.values.map(JSONValue.object)), "items": .array(items.values.map(JSONValue.object))])
            case "getBloomItem": return .object(items[args[0].string] ?? [:])
            default: throw NativeRequestRejected(status: 400, message: "Operazione non disponibile.")
            }
        }
        func siteAddFood(_ id: String, _ name: String) {
            changedAt[id] = stamp()
            foods[id] = ["id": .string(id), "name": .string(name), "family": .string("meal"), "basis": .string("g"), "kcal": .number(100), "protein": .number(5), "carbs": .number(10), "fat": .number(2), "fibre": .null, "micro": .object([:]), "aliases": .array([]), "note": .string(""), "app": .object([:])]
        }
        func siteDeleteFood(_ id: String) { foods.removeValue(forKey: id); changedAt.removeValue(forKey: id); tombstones[id] = stamp() }
        func row(_ i: Record) -> Record {
            var app = i; for k in ["id", "kind", "title", "urlString", "text", "notes", "tagIDs", "place", "archived", "trashedAt", "modifiedAt", "expectModifiedAt", "data"] { app.removeValue(forKey: k) }
            return ["id": i["id"]!, "kind": i["kind"] ?? .string("text"), "title": i["title"] ?? .string(""), "url": i["urlString"] ?? .string(""), "body": i["text"] ?? .string(""), "bodyLength": .int(i.text("text").count), "notes": i["notes"] ?? .string(""), "tags": i["tagIDs"] ?? .array([]), "place": i["place"] ?? .null, "archived": i["archived"] ?? .bool(false), "trashedAt": i["trashedAt"] ?? .null, "modifiedAt": .number(i.amount("modifiedAt") > 0 ? i.amount("modifiedAt") : clock), "app": .object(app)]
        }
    }

    private func setup() throws -> (NativeOnlineSync, NativeBloomStore, FakeServer, UserDefaults, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "online-sync-" + UUID().uuidString))
        let bloom = NativeBloomStore(directory: root)
        let sync = NativeOnlineSync(defaults: defaults, bloom: bloom)
        let server = FakeServer()
        sync.connect { method, args in try server.handle(method, args) }
        return (sync, bloom, server, defaults, root)
    }
    private func note(_ title: String) -> Record {
        ["id": .string(UUID().uuidString), "kind": .string("text"), "title": .string(title), "text": .string("testo"), "urlString": .string(""), "archived": .bool(false), "capturedAt": .number(700_000_000), "noteVersion": .int(1)]
    }

    /// FOLATE-KEY-2026-11-27: the server's «folate» becomes the app's «folateMass» (editor and Apple Health), once.
    func testServerFolateBecomesTheAppFolateKey() throws {
        let food = try XCTUnwrap(NativeOnlineSync.food(["id": .string("base-spinach"), "name": .string("Spinaci"), "family": .string("vegetable"),
            "kcal": .number(23), "protein": .number(2.9), "carbs": .number(3.6), "fat": .number(0.4),
            "micro": .object(["folate": .number(194), "epa": .number(0)]),
            "app": .object(["nutrientValues": .object(["folate": .object(["amount": .number(1), "estimateSource": .null])])])]))
        XCTAssertEqual(food.nutrientValues?["folateMass"]?.amount, 194)
        XCTAssertNil(food.nutrientValues?["folate"])
        XCTAssertEqual(food.nutrientValues?["epa"]?.amount, 0)
    }

    func testServerFoodKeepsAppOnlyFieldsAndSiteEdits() {
        let row: Record = ["id": .string("personal-1"), "name": .string("Uova bio"), "family": .string("egg"), "basis": .string("g"), "kcal": .number(143), "protein": .number(12.6), "carbs": .number(0.7), "fat": .number(9.9), "fibre": .null, "micro": .object(["calcium": .number(50)]), "aliases": .array([]), "note": .string(""), "app": .object(["pieces": .array([.object(["name": .string("Uovo"), "grams": .number(50)])])])]
        let food = NativeOnlineSync.food(row)
        XCTAssertEqual(food?.name, "Uova bio")
        XCTAssertEqual(food?.pieces?.first?.grams, 50)
        XCTAssertEqual(food?.nutrientValues?["calcium"]?.amount, 50)
        XCTAssertEqual(food?.family, .egg)
    }

    func testOneTimeTransferThenServerCopyWithoutDuplicates() async throws {
        let (sync, bloom, server, defaults, root) = try setup()
        defer { try? FileManager.default.removeItem(at: root) }
        try bloom.save(note("Ramen")); try bloom.save(note("Libro"))
        let food = try XCTUnwrap(NativeOnlineSync.food(["id": .string("personal-9"), "name": .string("Skyr"), "family": .string("dairy"), "kcal": .number(63), "protein": .number(11), "carbs": .number(4), "fat": .number(0.2)]))
        defaults.set(try JSONEncoder().encode([food]), forKey: NativeOnlineSync.foodsKey)
        await sync.run()
        XCTAssertEqual(server.items.count, 2); XCTAssertEqual(server.foods.count, 1)
        XCTAssertTrue(bloom.archive.lifeosTransferred93 == true)
        XCTAssertEqual(bloom.archive.lifeosPendingItems ?? [], [])
        XCTAssertEqual(bloom.archive.items.count, 2)
        XCTAssertTrue(defaults.bool(forKey: NativeOnlineSync.foodsTransferredKey))
        server.calls = []
        await sync.run()
        XCTAssertFalse(server.calls.contains("importBloom")); XCTAssertFalse(server.calls.contains("importFoods"))
        XCTAssertEqual(bloom.archive.items.count, 2)
    }

    func testLocalEditIsSentAndSiteEditWinsAConflict() async throws {
        let (sync, bloom, server, _, root) = try setup()
        defer { try? FileManager.default.removeItem(at: root) }
        var first = note("Prima"); try bloom.save(first)
        await sync.run()
        first = try XCTUnwrap(bloom.archive.items.first)
        first["title"] = .string("Dall'app"); try bloom.save(first)
        XCTAssertEqual(bloom.archive.lifeosPendingItems ?? [], [first.text("id")])
        await sync.run()
        XCTAssertEqual(server.items[first.text("id")]?.text("title"), "Dall'app")
        XCTAssertEqual(bloom.archive.lifeosPendingItems ?? [], [])
        // The site edits the same note after the device last read it.
        server.items[first.text("id")]?["title"] = .string("Dal sito")
        server.items[first.text("id")]?["modifiedAt"] = .number(server.clock + 100)
        var mine = try XCTUnwrap(bloom.archive.items.first); mine["title"] = .string("Vecchia copia"); try bloom.save(mine)
        await sync.run()
        XCTAssertEqual(bloom.archive.items.first?.text("title"), "Dal sito")
        XCTAssertEqual(server.items[first.text("id")]?.text("title"), "Dal sito")
    }

    func testNotesRemovedOnTheSiteDisappearAndSiteNotesAppear() async throws {
        let (sync, bloom, server, _, root) = try setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let gone = note("Da togliere"); try bloom.save(gone)
        await sync.run()
        sync.bloomReadInterval = 0 // read the site copy again right away
        server.items.removeValue(forKey: gone.text("id"))
        server.collections["tag-1"] = ["id": .string("tag-1"), "name": .string("Ristoranti"), "doc": .object([:])]
        server.items["site-1"] = ["id": .string("site-1"), "kind": .string("note"), "title": .string("Dal sito"), "url": .string(""), "body": .string("x"), "bodyLength": .int(1), "notes": .string(""), "tags": .array([.string("tag-1")]), "place": .null, "archived": .bool(false), "trashedAt": .null, "modifiedAt": .number(2_100_000_000), "app": .object([:])]
        await sync.run()
        XCTAssertEqual(bloom.archive.items.map { $0.text("title") }, ["Dal sito"])
        XCTAssertEqual(bloom.archive.items.first?.text("kind"), "text")
        XCTAssertEqual(bloom.archive.collections.first?.text("id"), "tag-1")
        // A site note can be edited and saved on the device.
        var edit = try XCTUnwrap(bloom.archive.items.first); edit["title"] = .string("Modificata")
        XCTAssertNoThrow(try bloom.save(edit))
    }

    /// APP-LAG-2026-11-26: without local changes the Bloom library is not read again before the interval.
    func testBloomIsNotReadAgainBeforeTheIntervalWithoutChanges() async throws {
        let (sync, bloom, server, _, root) = try setup()
        defer { try? FileManager.default.removeItem(at: root) }
        try bloom.save(note("Prima"))
        await sync.run()
        server.calls = []
        await sync.run()
        XCTAssertFalse(server.calls.contains("getBloom"), "no local change: no full read 30 s later")
        var edit = try XCTUnwrap(bloom.archive.items.first); edit["title"] = .string("Cambiata"); try bloom.save(edit)
        await sync.run()
        XCTAssertTrue(server.calls.contains("getBloom"), "a local change is followed by a read")
    }

    /// FOOD-SYNC-DELTA-2026-11-25: one full read, then only changes, and no check before the interval.
    func testFoodsAreFetchedAsChangesOnly() async throws {
        let (sync, _, server, defaults, root) = try setup()
        defer { try? FileManager.default.removeItem(at: root) }
        server.delta = true
        server.siteAddFood("site-1", "Pane del sito"); server.siteAddFood("site-2", "Riso del sito")
        await sync.run()
        func names() -> [String] {
            ((defaults.data(forKey: NativeOnlineSync.foodsKey)).flatMap { try? JSONDecoder().decode([NativeGenericFood].self, from: $0) } ?? []).map(\.name).sorted()
        }
        XCTAssertEqual(names(), ["Pane del sito", "Riso del sito"])
        server.calls = []
        server.siteAddFood("site-3", "Avena del sito"); server.siteDeleteFood("site-1")
        await sync.run()
        XCTAssertFalse(server.calls.contains("listFoodChanges"), "no check before the interval")
        XCTAssertFalse(server.calls.contains("listFoods"))
        defaults.removeObject(forKey: "lifeos-online-foods-checked-95")
        await sync.run()
        XCTAssertEqual(names(), ["Avena del sito", "Riso del sito"])
        XCTAssertFalse(server.calls.contains("listFoods"), "never the whole list again")
    }

    func testMergeKeepsUnsentPhoneEdits() throws {
        let mine = try XCTUnwrap(NativeOnlineSync.food(["id": .string("a"), "name": .string("Mia"), "family": .string("meal"), "kcal": .number(1), "protein": .number(1), "carbs": .number(1), "fat": .number(1)]))
        let server: Record = ["full": .bool(false), "foods": .array([.object(["id": .string("a"), "name": .string("Vecchia"), "family": .string("meal"), "kcal": .number(1), "protein": .number(1), "carbs": .number(1), "fat": .number(1)])]), "deleted": .array([.string("a")])]
        XCTAssertEqual(NativeOnlineSync.merge(local: [mine], changes: server, keeping: ["a"])?.map(\.name), ["Mia"])
        XCTAssertNil(NativeOnlineSync.merge(local: [mine], changes: ["full": .bool(false), "foods": .array([]), "deleted": .array([])], keeping: []))
    }

    func testOldServerChangesNothingOnTheDevice() async throws {
        let (sync, bloom, server, defaults, root) = try setup()
        defer { try? FileManager.default.removeItem(at: root) }
        server.offers = false
        try bloom.save(note("Solo qui"))
        await sync.run()
        XCTAssertNil(bloom.archive.lifeosTransferred93)
        XCTAssertFalse(defaults.bool(forKey: NativeOnlineSync.foodsTransferredKey))
        XCTAssertEqual(bloom.archive.items.count, 1)
        XCTAssertFalse(sync.online)
    }
}
