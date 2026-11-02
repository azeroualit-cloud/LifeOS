import XCTest
@testable import LifeOSProbe

@MainActor private final class NutritionWriterProbe: NativeNutritionWriting {
    var writes: [NativeNutritionEntry] = []
    var fail = false
    var denied = false
    func authorize() async throws { if denied { throw Message(text: "Denied") } }
    func write(_ entry: NativeNutritionEntry) async throws {
        writes.append(entry)
        if fail { throw Message(text: "Interrupted after remote save") }
    }
}
@MainActor final class NativeNutritionStoreTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func entry() -> NativeNutritionEntry { .init(id: UUID(), revision: 0, date: Date(), protein: 10, carbohydrate: 20, fat: 5, confirmed: false) }
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
