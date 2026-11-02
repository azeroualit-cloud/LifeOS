import XCTest
@testable import LifeOSProbe

@MainActor final class NativeBloomStoreTests: XCTestCase {
    private func note(_ id: UUID = UUID()) -> Record {
        ["id": .string(id.uuidString), "kind": .string("text"), "capturedAt": .number(100), "urlString": .string(""), "archived": .bool(false), "text": .string("Testo Unicode: caffè 🌱"), "noteVersion": .int(1)]
    }
    func testImportExportRestartAndIdempotentAttachments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data([0, 1, 2, 255]), id = UUID()
        var file = note(id); file["kind"] = .string("file"); file["text"] = .null
        file["fileName"] = .string("../../originale.pdf"); file["contentType"] = .string("com.adobe.pdf"); file["data"] = .string(bytes.base64EncodedString())
        let backup = NativeBloomArchive(collections: [], items: [file, note()])
        let encoded = try JSONEncoder().encode(backup), store = NativeBloomStore(directory: root)
        _ = try store.importBackup(encoded)
        XCTAssertEqual(store.archive.items.count, 2)
        let stored = try XCTUnwrap(store.archive.items.first { $0.text("id") == id.uuidString })
        XCTAssertNil(stored["data"]); XCTAssertEqual(stored.text("lifeosFileSHA256").count, 64)
        _ = try store.importBackup(encoded); XCTAssertEqual(store.archive.items.count, 2)
        let restarted = NativeBloomStore(directory: root)
        let restored = try JSONDecoder().decode(NativeBloomArchive.self, from: restarted.export())
        XCTAssertEqual(restored.items.first { $0.text("id") == id.uuidString }?["data"], .string(bytes.base64EncodedString()))
        XCTAssertEqual(restored.items.first { $0.text("id") == id.uuidString }?.text("fileName"), "../../originale.pdf")
    }
    func testConflictDoesNotOverwriteOrPublishPartialImport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root), original = note()
        try store.save(original)
        var conflict = original; conflict["text"] = .string("Divergente")
        let incoming = NativeBloomArchive(items: [note(), conflict])
        XCTAssertThrowsError(try store.importBackup(JSONEncoder().encode(incoming)))
        XCTAssertEqual(store.archive.items, [original])
        XCTAssertEqual(NativeBloomStore(directory: root).archive.items, [original])
    }
    func testMalformedMetadataAndInternalFileReferencesAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root)
        let variants: [(String, JSONValue)] = [
            ("place", .object(["name": .string("Fuori range"), "latitude": .number(91), "longitude": .number(0)])),
            ("capturedAt", .string("not a date")),
            ("tagIDs", .array([.string(UUID().uuidString)])),
            ("pinnedCategoryIDs", .array([.string(UUID().uuidString)])),
            ("noteLinks", .array([.string("file:///etc/passwd")])),
            ("lifeosFileSHA256", .string(String(repeating: "a", count: 64)))
        ]
        for (key, value) in variants {
            var item = note(); item[key] = value
            XCTAssertThrowsError(try store.preview(JSONEncoder().encode(NativeBloomArchive(items: [item]))), key)
        }
        XCTAssertTrue(store.archive.items.isEmpty)
    }
    func testCopyResolutionRemainsIdempotentAfterRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root), original = note()
        try store.save(original)
        var incoming = original; incoming["text"] = .string("Versione da conservare separatamente")
        let data = try JSONEncoder().encode(NativeBloomArchive(items: [incoming]))
        let conflicts = try store.conflicts(data); XCTAssertEqual(conflicts.count, 1)
        _ = try store.importBackup(data, resolutions: [conflicts[0].id: .copy])
        XCTAssertEqual(store.archive.items.count, 2)
        let restarted = NativeBloomStore(directory: root)
        XCTAssertTrue(try restarted.conflicts(data).isEmpty)
        _ = try restarted.importBackup(data)
        XCTAssertEqual(restarted.archive.items.count, 2)
        XCTAssertEqual(restarted.archive.lifeosImportReports?.last?.skipped, 1)
    }
    func testBulkCategoriesAndCategoryRemovalPreserveNotesAndOtherTags() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root), first = note(), second = note()
        try store.save(first); try store.save(second)
        let category = try store.addCategory("Viaggi"), remaining = try store.addCategory("Idee")
        let ids = Set([first.text("id"), second.text("id")])
        try store.updateNotes(ids, category: category); try store.updateNotes(ids, category: remaining)
        try store.removeCategory(category)
        XCTAssertEqual(store.archive.items.count, 2)
        for row in store.archive.items { XCTAssertEqual(row["tagIDs"]?.array.map(\.string), [remaining]) }
        try store.updateNotes(ids, archived: true)
        XCTAssertTrue(store.archive.items.allSatisfy { $0.flag("archived") })
        try store.updateNotes(ids, archived: false)
        XCTAssertTrue(store.archive.items.allSatisfy { !$0.flag("archived") })
    }
    func testImportedTrashIsNotAutomaticallyDeleted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var old = note(); old["archived"] = .bool(true); old["trashedAt"] = .number(1)
        let store = NativeBloomStore(directory: root)
        _ = try store.importBackup(JSONEncoder().encode(NativeBloomArchive(items: [old])))
        XCTAssertEqual(NativeBloomStore(directory: root).archive.items.count, 1)
    }
}
