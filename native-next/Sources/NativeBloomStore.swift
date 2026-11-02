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
}

struct NativeBloomArchive: Codable {
    var format = "Bloom"
    var version = 2
    var createdAt = Date().timeIntervalSinceReferenceDate
    var collections: [Record] = []
    var items: [Record] = []
    var lifeosImportReports: [NativeBloomImportReport]? = nil
}

@MainActor final class NativeBloomStore: ObservableObject {
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
        let stored = try externalize(record)
        next.items.removeAll { $0.text("id") == record.text("id") }; next.items.append(stored)
        try commit(next)
    }
    func trash(_ record: Record, restore: Bool = false) throws {
        var changed = record; changed["archived"] = .bool(!restore)
        changed["trashedAt"] = restore ? .null : .number(Date().timeIntervalSinceReferenceDate)
        try save(changed)
    }
    func export() throws -> Data {
        var result = archive; result.items = try archive.items.map(hydrated); result.createdAt = Date().timeIntervalSinceReferenceDate
        return try JSONEncoder().encode(result)
    }
    func preview(_ data: Data) throws -> NativeBloomArchive {
        guard data.count <= 100 * 1024 * 1024 else { throw Message(text: "Backup superiore a 100 MiB.") }
        let incoming = try JSONDecoder().decode(NativeBloomArchive.self, from: data)
        guard incoming.format == "Bloom", [1, 2].contains(incoming.version), incoming.items.count <= 10000, incoming.collections.count <= 2000 else { throw Message(text: "Formato o limiti backup non supportati.") }
        try NativeBloomValidation.validate(incoming)
        let categories = Set(incoming.collections.map { $0.text("id") })
        guard categories.count == incoming.collections.count, Set(incoming.items.map { $0.text("id") }).count == incoming.items.count else { throw Message(text: "Identificativi duplicati nel backup.") }
        var total = 0
        for category in incoming.collections {
            guard UUID(uuidString: category.text("id")) != nil, !category.text("name").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Message(text: "Categoria non valida.") }
        }
        for item in incoming.items {
            guard UUID(uuidString: item.text("id")) != nil, ["text", "link", "image", "file"].contains(item.text("kind")), item.text("lifeosFileSHA256").isEmpty else { throw Message(text: "Nota non valida.") }
            let tags = item["tagIDs"].flatMap { value -> [String]? in if case .array(let values) = value { return values.compactMap { if case .string(let s) = $0 { return s }; return nil } }; return nil } ?? (item.text("collectionID").isEmpty ? [] : [item.text("collectionID")])
            guard tags.allSatisfy(categories.contains) else { throw Message(text: "Categoria mancante nel backup.") }
            if item.text("kind") == "link" { guard let url = URL(string: item.text("urlString")), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw Message(text: "Link non valido.") } }
            var bytes = item.text("text").utf8.count + item.text("notes").utf8.count
            let files = item.records("noteFiles")
            for file in [item] + files {
                let raw = file.text("data")
                if !raw.isEmpty { guard let data = Data(base64Encoded: raw) else { throw Message(text: "Base64 non valido.") }; bytes += data.count }
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
        for category in incoming.collections {
            if let old = archive.collections.first(where: { $0.text("id") == category.text("id") }), try encoder.encode(old) != encoder.encode(category) {
                result.append(.init(id: "category:" + category.text("id"), title: category.text("name")))
            }
        }
        for item in incoming.items {
            if let old = archive.items.first(where: { $0.text("id") == item.text("id") }), try encoder.encode(hydrated(old)) != encoder.encode(item) {
                result.append(.init(id: "note:" + item.text("id"), title: item.text("title", fallback: String(item.text("text").prefix(80)))))
            }
        }
        return result
    }
    func importBackup(_ data: Data, resolutions: [String: NativeBloomConflictChoice] = [:]) throws -> String {
        let incoming = try preview(data)
        var next = archive, added = 0, skipped = 0
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var categoryMap: [String: String] = [:]
        for category in incoming.collections {
            let id = category.text("id")
            if let index = next.collections.firstIndex(where: { $0.text("id") == id }) {
                if try encoder.encode(next.collections[index]) != encoder.encode(category) {
                    guard let choice = resolutions["category:" + id] else { throw Message(text: "Risolvi il conflitto della categoria prima di importare.") }
                    switch choice {
                    case .keep: break
                    case .replace: next.collections[index] = category
                    case .copy:
                        var copy = category; let newID = UUID().uuidString
                        copy["id"] = .string(newID); categoryMap[id] = newID; next.collections.append(copy)
                    }
                }
            } else { next.collections.append(category) }
        }
        for source in incoming.items {
            var item = source
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
                case .copy: item["id"] = .string(UUID().uuidString); next.items.append(try externalize(item)); added += 1
                }
            } else { next.items.append(try externalize(item)); added += 1 }
        }
        // Keep the source before publishing the index. File orphans are harmless
        // and never referenced until the atomic index commit succeeds.
        try data.write(to: root.appendingPathComponent("backup-" + digest(data) + ".json"), options: [.atomic, .completeFileProtection])
        var reports = next.lifeosImportReports ?? []
        reports.append(.init(added: added, skipped: skipped, resolvedConflicts: resolutions.count))
        next.lifeosImportReports = reports
        try commit(next)
        return "Importate \(added) note; \(skipped) già presenti."
    }
}
