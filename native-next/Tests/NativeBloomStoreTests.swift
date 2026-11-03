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
    func testImportSnapshotPreservesReplacedContentAndAttachmentBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root)
        var original = note()
        original["noteFiles"] = .array([.object(["id": .string(UUID().uuidString), "name": .string("test.bin"), "type": .string("public.data"), "data": .string(Data([3, 1, 4]).base64EncodedString())])])
        try store.save(original)
        var incoming = original; incoming["text"] = .string("Updated")
        _ = try store.importBackup(JSONEncoder().encode(NativeBloomArchive(items: [incoming])), resolutions: ["note:" + original.text("id"): .replace])
        let snapshots = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("before-import-") }
        XCTAssertEqual(snapshots.count, 1)
        let snapshot = try store.preview(Data(contentsOf: XCTUnwrap(snapshots.first)))
        XCTAssertEqual(snapshot.items, [original])
        XCTAssertEqual(NativeBloomStore(directory: root).archive.items.first?.text("text"), "Updated")
    }
    func testSnapshotFailureLeavesExistingArchiveUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root, writeFile: { bytes, url in
            if url.lastPathComponent.hasPrefix("before-import-") { throw CocoaError(.fileWriteOutOfSpace) }
            try bytes.write(to: url, options: .atomic)
        })
        let original = note(); try store.save(original)
        XCTAssertThrowsError(try store.importBackup(JSONEncoder().encode(NativeBloomArchive(items: [note()]))))
        XCTAssertEqual(store.archive.items, [original])
        XCTAssertEqual(NativeBloomStore(directory: root).archive.items, [original])
    }
    func testConflictPreviewComparesOriginalAttachmentBytesWithoutRetainingBase64() {
        let bytes = Data([0, 1, 2, 255])
        let file: Record = ["name": .string("originale.bin"), "data": .string(bytes.base64EncodedString())]
        let preview = NativeBloomConflict.preview(["text": .string("Testo 🌱"), "noteFiles": .array([.object(file)])])
        XCTAssertEqual(preview.text("text"), "Testo 🌱")
        let attachment = preview.records("noteFiles")[0]
        XCTAssertNil(attachment["data"])
        XCTAssertEqual(attachment.integer("attachmentBytes"), bytes.count)
        XCTAssertEqual(attachment.text("attachmentSHA256"), "3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56")
        XCTAssertEqual(file["data"], .string(bytes.base64EncodedString()))
    }
    func testBothBackupVersionsRoundTripAllKindsNestedFilesPlacesAndOrderedLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let categories: [Record] = ["Idee 🌱", "Viaggi"].map { ["id": .string(UUID().uuidString), "name": .string($0), "createdAt": .number(100)] }
        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6LPQAAAAASUVORK5CYII="))
        let crop: Record = ["top": .number(0.1), "bottom": .number(0.2), "left": .number(0), "right": .number(0)]
        var text = note()
        text["text"] = .string("# Appunti Unicode 🌱\n\n| A | B |\n| --- | --- |\n| Caffè | 東京 |")
        text["collectionID"] = categories[0]["id"]
        text["tagIDs"] = .array([categories[1]["id"]!, categories[0]["id"]!])
        text["pinnedCategoryIDs"] = .array([categories[1]["id"]!])
        text["noteLinks"] = .array([.string("https://example.test/secondo"), .string("https://example.test/primo")])
        text["place"] = .object(["name": .string("Posto salvato"), "latitude": .number(43.7), "longitude": .number(11.2), "kind": .string("park")])
        text["futureMetadata"] = .object(["preserve": .bool(true), "unicode": .string("東京 🌱")])
        text["noteFiles"] = .array([
            .object(["id": .string(UUID().uuidString), "name": .string("foto.png"), "type": .string("public.png"), "data": .string(png.base64EncodedString()), "framing": .object(crop)]),
            .object(["id": .string(UUID().uuidString), "name": .string("dati-📎.bin"), "type": .string("public.data"), "data": .string(Data([0, 1, 2, 255]).base64EncodedString())])
        ])
        var link = note(); link["kind"] = .string("link"); link["text"] = .null; link["urlString"] = .string("https://example.test/nota")
        var image = note(); image["kind"] = .string("image"); image["text"] = .null; image["fileName"] = .string("originale.png"); image["contentType"] = .string("public.png"); image["data"] = .string(png.base64EncodedString()); image["imageFraming"] = .object(crop)
        var file = note(); file["kind"] = .string("file"); file["text"] = .null; file["fileName"] = .string("archiviato.bin"); file["data"] = .string(Data([9, 8, 7]).base64EncodedString()); file["archived"] = .bool(true); file["trashedAt"] = .number(1)
        let originals = [text, link, image, file]
        for version in [1, 2] {
            let directory = root.appendingPathComponent(String(version))
            var incoming = NativeBloomArchive(collections: categories, items: originals); incoming.version = version
            let store = NativeBloomStore(directory: directory)
            _ = try store.importBackup(JSONEncoder().encode(incoming))
            let restarted = NativeBloomStore(directory: directory)
            let exported = try JSONDecoder().decode(NativeBloomArchive.self, from: restarted.export())
            XCTAssertEqual(exported.version, 2); XCTAssertEqual(exported.collections, categories)
            XCTAssertEqual(exported.items.count, originals.count)
            for original in originals { XCTAssertEqual(exported.items.first { $0.text("id") == original.text("id") }, original) }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("files").path).count, 3)
            XCTAssertEqual(restarted.archive.lifeosImportReports?.last?.fileCount, 4)
            XCTAssertEqual(restarted.archive.lifeosImportReports?.last?.byteCount, png.count * 2 + 7)
        }
    }
    func testConflictDoesNotOverwriteOrPublishPartialImport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root), original = note()
        try store.save(original)
        var conflict = original; conflict["text"] = .string("Divergente")
        let incoming = NativeBloomArchive(items: [note(), conflict])
        let differences = try store.conflicts(JSONEncoder().encode(incoming))
        XCTAssertEqual(differences.first?.current["text"], original["text"])
        XCTAssertEqual(differences.first?.incoming["text"], .string("Divergente"))
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
    func testPermanentDeletionRetainsFilesSharedByAnotherNote() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root), bytes = Data([1, 2, 3])
        var first = note(), second = note()
        for index in 0..<2 {
            var row = index == 0 ? first : second
            row["kind"] = .string("file"); row["text"] = .null; row["data"] = .string(bytes.base64EncodedString()); row["fileName"] = .string("original.bin"); row["archived"] = .bool(true)
            if index == 0 { first = row } else { second = row }
            try store.save(row)
        }
        try store.deleteArchivedNote(first.text("id"))
        let retained = try XCTUnwrap(store.archive.items.first)
        XCTAssertEqual(try store.hydrated(retained)["data"], .string(bytes.base64EncodedString()))
        try store.deleteArchivedNote(second.text("id"))
        XCTAssertTrue(store.archive.items.isEmpty)
        XCTAssertThrowsError(try store.hydrated(retained))
    }
    func testCorruptIndexCannotProduceASuccessfulEmptyBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("index.json"), corrupt = Data("corrupt archive".utf8)
        try corrupt.write(to: index)
        let store = NativeBloomStore(directory: root)
        XCTAssertThrowsError(try store.export())
        XCTAssertThrowsError(try store.save(note()))
        XCTAssertEqual(try Data(contentsOf: index), corrupt)
    }
    func testEmptyFilesArePreservedAndWrongMetadataTypesAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root)
        var empty = note(); empty["kind"] = .string("file"); empty["text"] = .null; empty["fileName"] = .string("vuoto.txt"); empty["data"] = .string("")
        let data = try JSONEncoder().encode(NativeBloomArchive(items: [empty]))
        _ = try store.importBackup(data)
        let record = try XCTUnwrap(store.archive.items.first)
        XCTAssertEqual(try store.hydrated(record)["data"], .string(""))
        var invalid = note(); invalid["title"] = .bool(true)
        XCTAssertThrowsError(try store.preview(JSONEncoder().encode(NativeBloomArchive(items: [invalid]))))
    }
    func testOutOfSpaceAtIndexCommitRetainsArchiveAndRetryRecoversPreparedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var full = false
        let store = NativeBloomStore(directory: root, writeFile: { bytes, destination in
            if full && destination.lastPathComponent == "index.json" { throw CocoaError(.fileWriteOutOfSpace) }
            try bytes.write(to: destination, options: [.atomic, .completeFileProtection])
        })
        let original = note(); try store.save(original)
        let index = root.appendingPathComponent("index.json"), before = try Data(contentsOf: index)
        var file = note(); file["kind"] = .string("file"); file["text"] = .null
        file["fileName"] = .string("original.bin"); file["data"] = .string(Data([4, 5, 6]).base64EncodedString())
        let backup = try JSONEncoder().encode(NativeBloomArchive(items: [file]))
        full = true
        XCTAssertThrowsError(try store.importBackup(backup)) { error in
            XCTAssertEqual((error as NSError).code, NSFileWriteOutOfSpaceError)
        }
        XCTAssertEqual(store.archive.items, [original])
        XCTAssertEqual(try Data(contentsOf: index), before)
        XCTAssertEqual(NativeBloomStore(directory: root).archive.items, [original])
        full = false
        _ = try store.importBackup(backup)
        XCTAssertEqual(store.archive.items.count, 2)
        let restarted = NativeBloomStore(directory: root)
        XCTAssertEqual(try restarted.hydrated(try XCTUnwrap(restarted.archive.items.first { $0.text("id") == file.text("id") }))["data"], file["data"])
        _ = try restarted.importBackup(backup)
        XCTAssertEqual(restarted.archive.items.count, 2)
    }
    func testCorruptMediaAndUnknownBackupVersionsFailWithoutReplacingIndex() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NativeBloomStore(directory: root)
        var file = note(); file["kind"] = .string("file"); file["text"] = .null
        file["fileName"] = .string("original.bin"); file["data"] = .string(Data([1, 2]).base64EncodedString())
        try store.save(file)
        let index = root.appendingPathComponent("index.json"), before = try Data(contentsOf: index)
        let saved = try XCTUnwrap(store.archive.items.first)
        try Data([9, 9]).write(to: root.appendingPathComponent("files").appendingPathComponent(saved.text("lifeosFileSHA256")))
        XCTAssertThrowsError(try store.hydrated(saved)); XCTAssertThrowsError(try store.export())
        var future = NativeBloomArchive(); future.version = 99
        XCTAssertThrowsError(try store.importBackup(JSONEncoder().encode(future)))
        XCTAssertThrowsError(try store.importBackup(Data("broken JSON".utf8)))
        XCTAssertEqual(try Data(contentsOf: index), before)
    }
    func testCopiedCategoryAndNoteMappingsRemainIdempotentAcrossRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID().uuidString
        let category: Record = ["id": .string(id), "name": .string("Originale"), "createdAt": .number(100)]
        var original = note(); original["collectionID"] = .string(id); original["tagIDs"] = .array([.string(id)])
        let store = NativeBloomStore(directory: root)
        _ = try store.importBackup(JSONEncoder().encode(NativeBloomArchive(collections: [category], items: [original])))
        var changed = category; changed["name"] = .string("Diversa")
        let backup = try JSONEncoder().encode(NativeBloomArchive(collections: [changed], items: [original]))
        let conflicts = try store.conflicts(backup)
        XCTAssertEqual(conflicts.count, 2)
        _ = try store.importBackup(backup, resolutions: Dictionary(uniqueKeysWithValues: conflicts.map { ($0.id, NativeBloomConflictChoice.copy) }))
        let restarted = NativeBloomStore(directory: root)
        XCTAssertTrue(try restarted.conflicts(backup).isEmpty)
        _ = try restarted.importBackup(backup)
        XCTAssertEqual(restarted.archive.items.count, 2); XCTAssertEqual(restarted.archive.collections.count, 2)
        let copied = try XCTUnwrap(restarted.archive.items.first { $0.text("id") != original.text("id") })
        XCTAssertNotEqual(copied.text("collectionID"), id)
        XCTAssertEqual(copied["tagIDs"], .array([.string(copied.text("collectionID"))]))
        XCTAssertTrue(restarted.archive.collections.contains { $0.text("id") == copied.text("collectionID") && $0.text("name") == "Diversa" })
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
