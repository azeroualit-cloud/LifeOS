import XCTest
@testable import LifeOSProbe

@MainActor private final class NutritionWriterProbe: NativeNutritionWriting {
    var writes: [NativeNutritionEntry] = []
    var deletions: [UUID] = []
    var fail = false
    var denied = false
    func delete(_ entry: NativeNutritionEntry) async throws {
        deletions.append(entry.id)
        if fail { throw Message(text: "Interrupted deletion") }
    }
    func authorize() async throws { if denied { throw Message(text: "Denied") } }
    func write(_ entry: NativeNutritionEntry) async throws {
        writes.append(entry)
        if fail { throw Message(text: "Interrupted after remote save") }
    }
}
@MainActor final class NativeNutritionStoreTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func entry() -> NativeNutritionEntry { .init(id: UUID(), revision: 0, date: Date(), protein: 10, carbohydrate: 20, fat: 5, confirmed: false) }
    func testLegacyEntriesWithoutDeletionFieldRemainReadable() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(entry())) as? [String: Any])
        json.removeValue(forKey: "deletionPending")
        let decoded = try JSONDecoder().decode(NativeNutritionEntry.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.deletionPending)
        XCTAssertEqual(decoded.calories, 165)
    }
    func testDeniedDeletionRetainsRecoverableRow() async {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let writer = NutritionWriterProbe(), original = entry()
        let store = NativeNutritionStore(directory: root, writer: writer)
        let saved = await store.save(original); XCTAssertTrue(saved)
        writer.denied = true
        let removed = await store.delete(original.id); XCTAssertFalse(removed)
        XCTAssertEqual(store.entries.first?.id, original.id)
        XCTAssertEqual(store.entries.first?.deletionPending, true)
        XCTAssertTrue(writer.deletions.isEmpty)
    }
    func testInterruptedDeletionSurvivesRestartAndRetryKeepsIdentity() async {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let writer = NutritionWriterProbe(), original = entry()
        let store = NativeNutritionStore(directory: root, writer: writer)
        let saved = await store.save(original); XCTAssertTrue(saved)
        writer.fail = true
        let removed = await store.delete(original.id); XCTAssertFalse(removed)
        XCTAssertEqual(store.entries.first?.deletionPending, true)
        let restarted = NativeNutritionStore(directory: root, writer: writer)
        XCTAssertEqual(restarted.entries.first?.deletionPending, true)
        let blocked = await restarted.save(entry()); XCTAssertFalse(blocked)
        writer.fail = false
        let retried = await restarted.delete(original.id); XCTAssertTrue(retried)
        XCTAssertTrue(restarted.entries.isEmpty)
        XCTAssertTrue(NativeNutritionStore(directory: root, writer: writer).entries.isEmpty)
        XCTAssertEqual(writer.deletions, [original.id, original.id])
    }
    func testRetryAfterRestartRetainsIdentityRevisionAndPayload() async {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let writer = NutritionWriterProbe(); writer.fail = true
        let first = NativeNutritionStore(directory: root, writer: writer)
        let original = entry()
        let initial = await first.save(original); XCTAssertFalse(initial)
        XCTAssertFalse(first.entries[0].confirmed)
        let restarted = NativeNutritionStore(directory: root, writer: writer)
        writer.fail = false
        let retried = await restarted.save(restarted.entries[0], retry: true); XCTAssertTrue(retried)
        XCTAssertEqual(writer.writes.map(\.id), [original.id, original.id])
        XCTAssertEqual(writer.writes.map(\.revision), [1, 1])
        XCTAssertEqual(restarted.entries.count, 1); XCTAssertTrue(restarted.entries[0].confirmed)
        var edited = restarted.entries[0]; edited.protein = 30
        let savedEdit = await restarted.save(edited); XCTAssertTrue(savedEdit)
        XCTAssertEqual(writer.writes.last?.revision, 2)
        XCTAssertEqual(restarted.entries[0].calories, 245)
    }
    func testPendingPayloadCanBeCorrectedWithAHigherRevision() async {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let writer = NutritionWriterProbe(); writer.fail = true
        let store = NativeNutritionStore(directory: root, writer: writer)
        let original = entry()
        let failed = await store.save(original); XCTAssertFalse(failed)
        var corrected = original; corrected.protein = 20
        writer.fail = false
        let saved = await store.save(corrected); XCTAssertTrue(saved)
        XCTAssertEqual(writer.writes.map(\.revision), [1, 2])
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertTrue(store.entries[0].confirmed)
        XCTAssertEqual(store.entries[0].calories, 205)
    }
    func testDeniedAuthorizationDoesNotCreateAConfirmedOrPendingRecord() async {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let writer = NutritionWriterProbe(); writer.denied = true
        let store = NativeNutritionStore(directory: root, writer: writer)
        let saved = await store.save(entry()); XCTAssertFalse(saved)
        XCTAssertTrue(store.entries.isEmpty); XCTAssertTrue(writer.writes.isEmpty)
    }
    func testCorruptArchiveIsNotSilentlyOverwritten() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bytes = Data("broken".utf8); try bytes.write(to: root.appendingPathComponent("entries.json"))
        let store = NativeNutritionStore(directory: root, writer: NutritionWriterProbe())
        let saved = await store.save(entry()); XCTAssertFalse(saved)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("entries.json")), bytes)
    }
}
