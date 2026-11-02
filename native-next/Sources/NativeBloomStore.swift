import Foundation
import CryptoKit
import Combine

enum NativeBloomConflictChoice: String, CaseIterable { case keep, replace, copy }
struct NativeBloomConflict: Identifiable { let id: String; let title: String }

struct NativeBloomImportReport: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var added: Int
    var skipped: Int
    var resolvedConflicts: Int
    var categoryMappings: [String: String]? = nil
    var fileCount: Int? = nil
    var byteCount: Int? = nil
    var sourceSHA256: String? = nil
}

struct NativeBloomArchive: Codable {
    var format = "Bloom"
    var version = 2
    var createdAt = Date().timeIntervalSinceReferenceDate
    var collections: [Record] = []
    var items: [Record] = []
    var lifeosImportReports: [NativeBloomImportReport]? = nil
    var lifeosImportMappings: [String: String]? = nil
}

@MainActor final class NativeBloomStore: ObservableObject {
    static let shared = NativeBloomStore()
    @Published private(set) var archive = NativeBloomArchive()
    @Published var error: String?
    private let root: URL
    private var available = false
    init(directory: URL? = nil) {
        root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LifeOSBloom", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root.appendingPathComponent("files"), withIntermediateDirectories: true)
            let index = root.appendingPathComponent("index.json")
            if FileManager.default.fileExists(atPath: index.path) { archive = try JSONDecoder().decode(NativeBloomArchive.self, from: Data(contentsOf: index)) }
            available = true
        } catch { self.error = "Archivio Bloom non disponibile: " + error.localizedDescription }
    }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func externalize(_ source: Record) throws -> Record {
        var record = source
        if let value = record["data"], case .string(let raw) = value {
            guard let bytes = Data(base64Encoded: raw) else { throw Message(text: "Allegato Base64 non valido.") }
            let hash = digest(bytes), path = root.appendingPathComponent("files").appendingPathComponent(hash)
            if !FileManager.default.fileExists(atPath: path.path) { try bytes.write(to: path, options: [.atomic, .completeFileProtection]) }
            guard digest(try Data(contentsOf: path)) == hash else { throw Message(text: "Verifica allegato non riuscita.") }
            record.removeValue(forKey: "data"); record["lifeosFileSHA256"] = .string(hash); record["lifeosFileBytes"] = .int(bytes.count)
        }
        if case .array(let files)? = record["noteFiles"] {
            record["noteFiles"] = .array(try files.map { value in
                guard case .object(let file) = value else { throw Message(text: "Allegato non valido.") }
                return .object(try externalize(file))
            })
        }
        return record
    }
    func hydrated(_ source: Record) throws -> Record {
        var record = source
        let hash = record.text("lifeosFileSHA256")
        if !hash.isEmpty {
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else { throw Message(text: "Riferimento allegato non valido.") }
            let bytes = try Data(contentsOf: root.appendingPathComponent("files").appendingPathComponent(hash))
            guard digest(bytes) == hash, bytes.count == record.integer("lifeosFileBytes") else { throw Message(text: "Allegato danneggiato.") }
            record["data"] = .string(bytes.base64EncodedString()); record.removeValue(forKey: "lifeosFileSHA256"); record.removeValue(forKey: "lifeosFileBytes")
        }
        if case .array(let files)? = record["noteFiles"] {
            record["noteFiles"] = .array(try files.map { value in
                guard case .object(let file) = value else { throw Message(text: "Allegato non valido.") }
                return .object(try hydrated(file))
            })
        }
        return record
    }
    private func commit(_ next: NativeBloomArchive) throws {
        guard available else { throw Message(text: "Archivio non disponibile: nessuna modifica salvata.") }
        try JSONEncoder().encode(next).write(to: root.appendingPathComponent("index.json"), options: [.atomic, .completeFileProtection])
        archive = next
    }
    func save(_ record: Record) throws {
        var next = archive
        var validation = archive
        validation.items = try archive.items.filter { $0.text("id") != record.text("id") }.map(hydrated) + [hydrated(record)]
        _ = try preview(JSONEncoder().encode(validation))
        let stored = try externalize(record)
        next.items.removeAll { $0.text("id") == record.text("id") }; next.items.append(stored)
        try commit(next)
    }
    func addCategory(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.utf8.count <= 1024 else { throw Message(text: "Inserisci un nome categoria valido.") }
        if let existing = archive.collections.first(where: { $0.text("name").localizedCaseInsensitiveCompare(clean) == .orderedSame }) { return existing.text("id") }
        var next = archive; let id = UUID().uuidString
        guard next.collections.count < 2000 else { throw Message(text: "Limite categorie raggiunto.") }
        next.collections.append(["id": .string(id), "name": .string(clean), "createdAt": .number(Date().timeIntervalSinceReferenceDate)])
        try commit(next); return id
    }
    func setClassifiedPlaceKind(_ id: String, expected: Record, kind: String) throws -> Bool {
        guard let index = archive.items.firstIndex(where: { $0.text("id") == id }), archive.items[index].record("place") == expected, expected["kind"] == nil || expected["kind"] == .null else { return false }
        var next = archive, place = expected
        place["kind"] = .string(kind); next.items[index]["place"] = .object(place)
        next.items[index]["modifiedAt"] = .number(Date().timeIntervalSinceReferenceDate)
        try commit(next); return true
    }
    func primaryFileURL(_ row: Record) -> URL? {
        let source: Record
        if row.text("kind") == "image" { source = row }
        else if let file = row.records("noteFiles").first(where: { $0.text("type").hasPrefix("public.image") || ["public.jpeg", "public.png", "public.heic"].contains($0.text("type")) }) { source = file }
        else { return nil }
        let hash = source.text("lifeosFileSHA256")
        guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else { return nil }
        return root.appendingPathComponent("files").appendingPathComponent(hash)
    }
    func updateNotes(_ ids: Set<String>, category: String? = nil, archived: Bool? = nil) throws {
        guard !ids.isEmpty else { return }
        guard ids.isSubset(of: Set(archive.items.map { $0.text("id") })) else { throw Message(text: "Una nota selezionata non è più disponibile.") }
        if let category { guard archive.collections.contains(where: { $0.text("id") == category }) else { throw Message(text: "Categoria non disponibile.") } }
        var next = archive
        let now = Date().timeIntervalSinceReferenceDate
        for index in next.items.indices where ids.contains(next.items[index].text("id")) {
            var row = next.items[index]
            if let category {
                var tags = Set(row["tagIDs"]?.array.map(\.string) ?? (row.text("collectionID").isEmpty ? [] : [row.text("collectionID")]))
                tags.insert(category); row["tagIDs"] = .array(tags.sorted().map(JSONValue.string))
                if row.text("collectionID").isEmpty { row["collectionID"] = .string(category) }
            }
            if let archived { row["archived"] = .bool(archived); row["trashedAt"] = archived ? .number(now) : .null }
            row["modifiedAt"] = .number(now); next.items[index] = row
        }
        try commit(next)
    }
    func renameCategory(_ id: String, name: String) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.utf8.count <= 1024, let index = archive.collections.firstIndex(where: { $0.text("id") == id }) else { throw Message(text: "Categoria o nome non valido.") }
        guard !archive.collections.contains(where: { $0.text("id") != id && $0.text("name").localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { throw Message(text: "Esiste già una categoria con questo nome.") }
        var next = archive; next.collections[index]["name"] = .string(clean); next.collections[index]["modifiedAt"] = .number(Date().timeIntervalSinceReferenceDate)
        try commit(next)
    }
    func removeCategory(_ id: String) throws {
        var next = archive
        next.collections.removeAll { $0.text("id") == id }
        for index in next.items.indices {
            var row = next.items[index]
            let tags = Set(row["tagIDs"]?.array.map(\.string) ?? (row.text("collectionID").isEmpty ? [] : [row.text("collectionID")])).subtracting([id])
            row["tagIDs"] = .array(tags.sorted().map(JSONValue.string))
            row["pinnedCategoryIDs"] = .array((row["pinnedCategoryIDs"]?.array ?? []).filter { tags.contains($0.string) })
            if row.text("collectionID") == id { row["collectionID"] = tags.sorted().first.map(JSONValue.string) ?? .null }
            next.items[index] = row
        }
        try commit(next)
    }
    func deleteArchivedNote(_ id: String) throws {
        guard let note = archive.items.first(where: { $0.text("id") == id }), note.flag("archived") else { throw Message(text: "Puoi eliminare definitivamente solo una nota nel Cestino.") }
        func hashes(_ row: Record) -> Set<String> {
            Set(([row] + row.records("noteFiles")).map { $0.text("lifeosFileSHA256") }.filter { $0.count == 64 && $0.allSatisfy({ $0.isHexDigit }) })
        }
        var next = archive; next.items.removeAll { $0.text("id") == id }
        let retained = next.items.reduce(into: Set<String>()) { $0.formUnion(hashes($1)) }
        let removable = hashes(note).subtracting(retained)
        try commit(next)
        for hash in removable {
            do { try FileManager.default.removeItem(at: root.appendingPathComponent("files").appendingPathComponent(hash)) }
            catch { self.error = "Nota eliminata dalla Libreria; alcuni file locali non sono stati rimossi. I backup restano conservati." }
        }
    }
    func trash(_ record: Record, restore: Bool = false) throws {
        var changed = record; changed["archived"] = .bool(!restore)
        changed["trashedAt"] = restore ? .null : .number(Date().timeIntervalSinceReferenceDate)
        try save(changed)
    }
    func export() throws -> Data {
        guard available else { throw Message(text: "Archivio Bloom non leggibile: esportazione interrotta per non creare un backup vuoto.") }
        var result = archive; result.items = try archive.items.map(hydrated); result.createdAt = Date().timeIntervalSinceReferenceDate
        return try JSONEncoder().encode(result)
    }
    func preview(_ data: Data) throws -> NativeBloomArchive {
        guard data.count <= 100 * 1024 * 1024 else { throw Message(text: "Backup superiore a 100 MiB.") }
        var incoming = try JSONDecoder().decode(NativeBloomArchive.self, from: data)
        func normalized(_ source: Record) -> Record {
            var row = source
            for key in ["id", "collectionID"] {
                if let id = UUID(uuidString: row.text(key)) { row[key] = .string(id.uuidString) }
            }
            for key in ["tagIDs", "pinnedCategoryIDs"] {
                if case .array(let values)? = row[key] { row[key] = .array(values.map { value in
                    if case .string(let raw) = value, let id = UUID(uuidString: raw) { return .string(id.uuidString) }; return value
                }) }
            }
            if case .array(let values)? = row["noteFiles"] { row["noteFiles"] = .array(values.map { value in if case .object(let file) = value { return .object(normalized(file)) }; return value }) }
            return row
        }
        incoming.collections = incoming.collections.map(normalized)
        incoming.items = incoming.items.map(normalized)
        guard incoming.format == "Bloom", [1, 2].contains(incoming.version), incoming.items.count <= 10000, incoming.collections.count <= 2000 else { throw Message(text: "Formato o limiti backup non supportati.") }
        try NativeBloomValidation.validate(incoming)
        let categories = Set(incoming.collections.map { $0.text("id") })
        guard categories.count == incoming.collections.count, Set(incoming.items.map { $0.text("id") }).count == incoming.items.count else { throw Message(text: "Identificativi duplicati nel backup.") }
        var total = incoming.collections.reduce(0) { $0 + $1.text("name").utf8.count }
        for category in incoming.collections {
            guard UUID(uuidString: category.text("id")) != nil, !category.text("name").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Message(text: "Categoria non valida.") }
        }
        for item in incoming.items {
            guard UUID(uuidString: item.text("id")) != nil, ["text", "link", "image", "file"].contains(item.text("kind")), item.text("lifeosFileSHA256").isEmpty else { throw Message(text: "Nota non valida.") }
            let tags = item["tagIDs"].flatMap { value -> [String]? in if case .array(let values) = value { return values.compactMap { if case .string(let s) = $0 { return s }; return nil } }; return nil } ?? (item.text("collectionID").isEmpty ? [] : [item.text("collectionID")])
            guard tags.allSatisfy(categories.contains) else { throw Message(text: "Categoria mancante nel backup.") }
            if item.text("kind") == "link" { guard let url = URL(string: item.text("urlString")), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw Message(text: "Link non valido.") } }
            total += ["urlString", "title", "fileName", "contentType"].reduce(0) { $0 + item.text($1).utf8.count }
            total += item.record("place").text("name").utf8.count
            total += (item["noteLinks"]?.array ?? []).reduce(0) { $0 + $1.string.utf8.count }
            var bytes = item.text("text").utf8.count + item.text("notes").utf8.count
            let files = item.records("noteFiles")
            total += files.reduce(0) { $0 + $1.text("name").utf8.count + $1.text("type").utf8.count }
            for file in [item] + files {
                if case .string(let raw)? = file["data"] { guard let data = Data(base64Encoded: raw) else { throw Message(text: "Base64 non valido.") }; bytes += data.count }
                else if ["image", "file"].contains(item.text("kind")), file.text("id") == item.text("id") { throw Message(text: "File principale mancante.") }
            }
            guard bytes <= 25 * 1024 * 1024 else { throw Message(text: "Nota superiore a 25 MiB.") }
            total += bytes
        }
        guard total <= 60 * 1024 * 1024 else { throw Message(text: "Contenuti superiori a 60 MiB.") }
        return incoming
    }
    func conflicts(_ data: Data) throws -> [NativeBloomConflict] {
        let incoming = try preview(data)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var result: [NativeBloomConflict] = []
        let sourceHash = digest(data)
        let mappings = archive.lifeosImportMappings ?? [:]
        for source in incoming.collections {
            var category = source
            if let mapped = mappings[sourceHash + ":category:" + source.text("id")] { category["id"] = .string(mapped) }
            if let old = archive.collections.first(where: { $0.text("id") == category.text("id") }), try encoder.encode(old) != encoder.encode(category) {
                result.append(.init(id: "category:" + source.text("id"), title: category.text("name")))
            }
        }
        for source in incoming.items {
            var item = source
            if let mapped = mappings[sourceHash + ":note:" + source.text("id")] { item["id"] = .string(mapped) }
            for key in ["collectionID"] { if let mapped = mappings[sourceHash + ":category:" + item.text(key)] { item[key] = .string(mapped) } }
            for key in ["tagIDs", "pinnedCategoryIDs"] {
                if case .array(let values)? = item[key] { item[key] = .array(values.map { value in .string(mappings[sourceHash + ":category:" + value.string] ?? value.string) }) }
            }
            if let old = archive.items.first(where: { $0.text("id") == item.text("id") }), try encoder.encode(hydrated(old)) != encoder.encode(item) {
                result.append(.init(id: "note:" + source.text("id"), title: item.text("title", fallback: String(item.text("text").prefix(80)))))
            }
        }
        let categoryConflicts = Set(result.filter { $0.id.hasPrefix("category:") }.map { String($0.id.dropFirst("category:".count)) })
        for item in incoming.items where archive.items.contains(where: { $0.text("id") == item.text("id") }) {
            let tags = Set(item["tagIDs"]?.array.map(\.string) ?? [item.text("collectionID")])
            if !tags.isDisjoint(with: categoryConflicts), !result.contains(where: { $0.id == "note:" + item.text("id") }) {
                result.append(.init(id: "note:" + item.text("id"), title: item.text("title", fallback: "Relazioni categoria della nota")))
            }
        }
        return result
    }
    func importBackup(_ data: Data, resolutions: [String: NativeBloomConflictChoice] = [:]) throws -> String {
        let incoming = try preview(data)
        var next = archive, added = 0, skipped = 0
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var categoryMap: [String: String] = [:]
        var mappings = next.lifeosImportMappings ?? [:]
        let sourceHash = digest(data)
        for source in incoming.collections {
            var category = source
            let originalID = source.text("id")
            if let mapped = mappings[sourceHash + ":category:" + originalID] { category["id"] = .string(mapped); categoryMap[originalID] = mapped }
            let id = category.text("id")
            if let index = next.collections.firstIndex(where: { $0.text("id") == id }) {
                if try encoder.encode(next.collections[index]) != encoder.encode(category) {
                    guard let choice = resolutions["category:" + originalID] else { throw Message(text: "Risolvi il conflitto della categoria prima di importare.") }
                    switch choice {
                    case .keep: break
                    case .replace: next.collections[index] = category
                    case .copy:
                        var copy = category; let newID = UUID().uuidString
                        copy["id"] = .string(newID); categoryMap[originalID] = newID; mappings[sourceHash + ":category:" + originalID] = newID; next.collections.append(copy)
                    }
                }
            } else { next.collections.append(category) }
        }
        for source in incoming.items {
            var item = source
            if let mapped = mappings[sourceHash + ":note:" + source.text("id")] { item["id"] = .string(mapped) }
            if let mapped = categoryMap[item.text("collectionID")] { item["collectionID"] = .string(mapped) }
            for key in ["tagIDs", "pinnedCategoryIDs"] {
                if case .array(let values)? = item[key] { item[key] = .array(values.map { value in
                    if case .string(let id) = value, let mapped = categoryMap[id] { return .string(mapped) }; return value
                }) }
            }
            if let index = next.items.firstIndex(where: { $0.text("id") == item.text("id") }) {
                if try encoder.encode(hydrated(next.items[index])) == encoder.encode(item) { skipped += 1; continue }
                guard let choice = resolutions["note:" + source.text("id")] else { throw Message(text: "Risolvi il conflitto della nota prima di importare.") }
                switch choice {
                case .keep: skipped += 1
                case .replace: next.items[index] = try externalize(item)
                case .copy:
                    let newID = UUID().uuidString; item["id"] = .string(newID)
                    mappings[sourceHash + ":note:" + source.text("id")] = newID
                    next.items.append(try externalize(item)); added += 1
                }
            } else { next.items.append(try externalize(item)); added += 1 }
        }
        // Keep the source before publishing the index. File orphans are harmless
        // and never referenced until the atomic index commit succeeds.
        try data.write(to: root.appendingPathComponent("backup-" + digest(data) + ".json"), options: [.atomic, .completeFileProtection])
        var reports = next.lifeosImportReports ?? []
        let files = incoming.items.flatMap { item -> [Record] in (item["data"] != nil && item["data"] != .null ? [item] : []) + item.records("noteFiles") }
        let bytes = files.reduce(0) { $0 + (Data(base64Encoded: $1.text("data"))?.count ?? 0) }
        reports.append(.init(added: added, skipped: skipped, resolvedConflicts: resolutions.count, categoryMappings: categoryMap, fileCount: files.count, byteCount: bytes, sourceSHA256: digest(data)))
        next.lifeosImportReports = reports
        next.lifeosImportMappings = mappings
        try commit(next)
        return "Importate \(added) note; \(skipped) già presenti."
    }
}
