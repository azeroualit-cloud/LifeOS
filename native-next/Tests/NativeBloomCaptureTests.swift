import XCTest
@testable import LifeOSProbe

@MainActor final class NativeBloomCaptureTests: XCTestCase {
    func testInterruptedCaptureCanRetryWithoutOverwritingLaterEdits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocked = root.appendingPathComponent("blocked"); try Data("file".utf8).write(to: blocked)
        let inboxRoot = root.appendingPathComponent("inbox")
        let inbox = NativeBloomCaptureInbox(directory: inboxRoot)
        let row: Record = ["id": .string(UUID().uuidString), "kind": .string("link"), "capturedAt": .number(100), "urlString": .string("https://example.com"), "archived": .bool(false)]
        XCTAssertThrowsError(try inbox.capture(row, in: NativeBloomStore(directory: blocked)))
        XCTAssertEqual(inbox.requests.count, 1)
        let restarted = NativeBloomCaptureInbox(directory: inboxRoot)
        let store = NativeBloomStore(directory: root.appendingPathComponent("library"))
        var edited = row; edited["title"] = .string("Modifica già salvata")
        try store.save(edited)
        try restarted.retry(restarted.requests[0], in: store)
        XCTAssertTrue(restarted.requests.isEmpty)
        XCTAssertEqual(store.archive.items.count, 1)
        XCTAssertEqual(store.archive.items[0].text("title"), "Modifica già salvata")
    }
}
