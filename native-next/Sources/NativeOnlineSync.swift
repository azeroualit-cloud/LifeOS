import Foundation

/// Bloom and personal foods live on the server (BUILD93-REQUEST-2026-11-21).
/// The device keeps a cache and the attachment bytes; the server decides.
/// The first time the server offers these methods, everything on the device is
/// sent once (repeatable without duplicates), then the server copy is read back.
/// If the server does not offer them yet, nothing changes on the device.
@MainActor final class NativeOnlineSync: ObservableObject {
    static let shared = NativeOnlineSync()
    typealias Reader = (String, [JSONValue]) async throws -> JSONValue

    @Published private(set) var online = false
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?

    static let foodsKey = "lifeos-personal-foods-v1"
    static let foodsTransferredKey = "lifeos-online-foods-transferred-93"
    static let foodsPendingKey = "lifeos-online-foods-pending-93"

    private var reader: Reader?
    private var again = false
    private let defaults: UserDefaults
    private let bloom: NativeBloomStore

    init(defaults: UserDefaults = .standard, bloom: NativeBloomStore? = nil) {
        self.defaults = defaults
        self.bloom = bloom ?? .shared
    }

    func connect(_ reader: @escaping Reader) {
        self.reader = reader
        bloom.onLocalChange = { [weak self] in self?.soon() }
    }

    func soon() {
        guard reader != nil else { return }
        Task { await self.run() }
    }

    private var current: Task<Void, Never>?
    func run() async {
        guard reader != nil else { return }
        if let current { again = true; await current.value; return }
        let task = Task { await self.loop() }
        current = task
        await task.value
        current = nil
    }

    private func loop() async {
        repeat {
            again = false
            guard let reader else { return }
            do {
                try await syncFoods(reader)
                try await syncBloom(reader)
                online = true; lastSync = Date(); lastError = nil
            } catch let error as NativeRequestRejected where error.message.contains("Operazione non disponibile") {
                online = false // Worker not updated yet: keep working on the device.
                return
            } catch {
                lastError = error.localizedDescription
                return
            }
        } while again
    }

    // MARK: Foods

    struct FoodChange: Codable { var id: String; var delete: Bool }

    private var pendingFoods: [FoodChange] {
        get { (defaults.data(forKey: Self.foodsPendingKey)).flatMap { try? JSONDecoder().decode([FoodChange].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.foodsPendingKey) }
    }

    /// Called by the food list after it saved its cache.
    func foodsChanged(old: [NativeGenericFood], new: [NativeGenericFood]) {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let before = Dictionary(old.map { ($0.id, (try? encoder.encode($0)) ?? Data()) }, uniquingKeysWith: { a, _ in a })
        let after = Set(new.map(\.id))
        var pending = pendingFoods
        for food in new where before[food.id] != (try? encoder.encode(food)) { pending.removeAll { $0.id == food.id }; pending.append(.init(id: food.id, delete: false)) }
        for id in before.keys where !after.contains(id) { pending.removeAll { $0.id == id }; pending.append(.init(id: id, delete: true)) }
        pendingFoods = pending
        soon()
    }

    private func localFoods() -> [NativeGenericFood] {
        guard let data = defaults.data(forKey: Self.foodsKey), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([NativeGenericFood].self, from: data)) ?? []
    }

    private func appJSON(_ food: NativeGenericFood) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(food))
    }

    private func syncFoods(_ read: Reader) async throws {
        _ = try await read("listFoods", []) // also tells whether the server offers these methods
        if !defaults.bool(forKey: Self.foodsTransferredKey) {
            let foods = localFoods()
            for start in stride(from: 0, to: foods.count, by: 200) {
                let chunk = try foods[start..<min(foods.count, start + 200)].map(appJSON)
                _ = try await read("importFoods", [.array(chunk)])
            }
            defaults.set(true, forKey: Self.foodsTransferredKey)
            pendingFoods = []
        }
        let local = Dictionary(localFoods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var remaining: [FoodChange] = []
        for change in pendingFoods {
            do {
                if change.delete { _ = try await read("deleteFood", [.string(change.id)]) }
                else if let food = local[change.id] { _ = try await read("saveFood", [try appJSON(food)]) }
            } catch let error as NativeRequestRejected where !error.message.contains("Operazione non disponibile") {
                continue // A rejected food is dropped: the server copy is read back below.
            } catch { remaining.append(change) }
        }
        pendingFoods = remaining
        let value = try await read("listFoods", [])
        guard remaining.isEmpty else { return } // keep unsent edits visible until they reach the server
        let foods = value.object.records("foods").compactMap(Self.food)
        defaults.set(try JSONEncoder().encode(foods), forKey: Self.foodsKey)
    }

    /// Server row → app food. App-only fields (pieces, units…) come from `app`, the
    /// canonical fields the site can edit come from the row.
    nonisolated static func food(_ row: Record) -> NativeGenericFood? {
        var json = row.record("app")
        json["id"] = .string(row.text("id"))
        json["name"] = .string(row.text("name"))
        json["family"] = .string(NativeGenericFood.Family(rawValue: row.text("family")) == nil ? "meal" : row.text("family"))
        json["brand"] = row.text("brand").isEmpty ? .null : .string(row.text("brand"))
        json["measurementBasis"] = .string(row.text("basis") == "ml" ? "ml" : "g")
        json["nutritionNotDeclared"] = row.flag("notDeclared") ? .bool(true) : .null
        json["calories"] = .number(row.amount("kcal"))
        json["protein"] = .number(row.amount("protein"))
        json["carbohydrate"] = .number(row.amount("carbs"))
        json["fat"] = .number(row.amount("fat"))
        json["fibre"] = row["fibre"] == nil || row["fibre"] == .null ? .null : .number(row.amount("fibre"))
        json["aliases"] = .array(row["aliases"]?.array ?? [])
        json["dataNote"] = row.text("note").isEmpty ? json["dataNote"] ?? .null : .string(row.text("note"))
        var nutrients = json.record("nutrientValues")
        for (key, value) in row.record("micro") {
            let previous = nutrients[key]?.object ?? [:]
            nutrients[key] = .object(["amount": .number(value.number), "estimateSource": previous["estimateSource"] ?? .null])
        }
        for key in nutrients.keys where row.record("micro")[key] == nil { nutrients.removeValue(forKey: key) }
        json["nutrientValues"] = nutrients.isEmpty ? .null : .object(nutrients)
        guard let data = try? JSONEncoder().encode(JSONValue.object(json)) else { return nil }
        return try? JSONDecoder().decode(NativeGenericFood.self, from: data)
    }

    // MARK: Bloom

    private static let appleEpoch = 978_307_200.0
    nonisolated static func unix(_ reference: Double) -> Double { reference > 1.5e9 ? reference : reference + appleEpoch }
    nonisolated static func reference(_ unix: Double) -> Double { unix > 1.5e9 ? unix - appleEpoch : unix }

    /// Local note → server payload. Attachment bytes stay on the device.
    nonisolated static func payload(_ item: Record) -> Record {
        var out = item
        out.removeValue(forKey: "data")
        if case .array(let files)? = item["noteFiles"] {
            out["noteFiles"] = .array(files.map { file in var f = file.object; f.removeValue(forKey: "data"); return .object(f) })
        }
        for key in ["modifiedAt", "trashedAt", "createdAt", "capturedAt"] {
            if let v = item[key], case .number(let n) = v { out[key] = .number(unix(n)) }
        }
        return out
    }

    /// Server note → local note, keeping the attachments this device already has.
    nonisolated static func note(_ row: Record, local: Record?) -> Record {
        var out = row.record("app")
        out.removeValue(forKey: "noteFiles") // file bytes exist only where they were attached
        for (key, value) in local ?? [:] where ["data", "lifeosFileSHA256", "lifeosFileBytes", "noteFiles", "fileName", "contentType"].contains(key) { out[key] = value }
        out["id"] = .string(row.text("id"))
        let kind = row.text("kind")
        out["kind"] = .string(["text", "link", "image", "file"].contains(kind) ? kind : (row.text("url").isEmpty ? "text" : "link"))
        out["title"] = .string(row.text("title"))
        out["urlString"] = .string(row.text("url"))
        out["notes"] = .string(row.text("notes"))
        let tags = row["tags"]?.array ?? []
        out["tagIDs"] = .array(tags)
        if out.text("collectionID").isEmpty || !tags.contains(.string(out.text("collectionID"))) { out["collectionID"] = tags.first ?? .null }
        out["place"] = row["place"].flatMap { $0 == .null ? nil : $0 } ?? .null
        out["archived"] = .bool(row.flag("archived"))
        out["trashedAt"] = row["trashedAt"].flatMap { $0 == .null ? nil : .number(reference($0.number)) } ?? .null
        out["modifiedAt"] = .number(reference(row.amount("modifiedAt")))
        for key in ["createdAt", "capturedAt"] { if let v = out[key], case .number(let n) = v { out[key] = .number(reference(n)) } }
        // A note created elsewhere whose file is not on this device is shown as a note.
        if ["image", "file"].contains(out.text("kind")), out.text("lifeosFileSHA256").isEmpty, out["data"] == nil {
            out["kind"] = .string(out.text("urlString").isEmpty ? "text" : "link")
        }
        // Shape the app validates: text only on text notes, a capture date on every note.
        if out.text("kind") == "text" {
            out["text"] = .string(row.text("body"))
            if out.text("text").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && out.text("title").isEmpty { out["title"] = .string("Nota") }
        } else {
            out["text"] = .null
            if !row.text("body").isEmpty && out.text("notes").isEmpty { out["notes"] = .string(row.text("body")) }
        }
        if out["capturedAt"] == nil || out["capturedAt"] == .null { out["capturedAt"] = out["createdAt"] ?? out["modifiedAt"] ?? .number(0) }
        return out
    }

    private func syncBloom(_ read: Reader) async throws {
        var archive = bloom.archive
        if archive.lifeosTransferred93 != true {
            let collections = archive.collections.map(JSONValue.object)
            let items = archive.items.map { JSONValue.object(Self.payload($0)) }
            var first = true
            for start in stride(from: 0, to: max(items.count, 1), by: 60) {
                let chunk = Array(items[min(start, items.count)..<min(items.count, start + 60)])
                let batch: Record = ["collections": .array(first ? Array(collections.prefix(300)) : []), "items": .array(chunk)]
                first = false
                if chunk.isEmpty && collections.isEmpty { break }
                _ = try await read("importBloom", [.object(batch)])
            }
            for extra in stride(from: 300, to: collections.count, by: 300) {
                _ = try await read("importBloom", [.object(["collections": .array(Array(collections[extra..<min(collections.count, extra + 300)])), "items": .array([])])])
            }
            archive = bloom.archive
            archive.lifeosTransferred93 = true
            archive.lifeosPendingItems = []; archive.lifeosDeletedItems = []
            archive.lifeosPendingCollections = []; archive.lifeosDeletedCollections = []
            try bloom.applyServer(archive)
        }
        try await sendBloomChanges(read)
        try await readBloom(read)
    }

    private func sendBloomChanges(_ read: Reader) async throws {
        let snapshot = bloom.archive
        var modified = snapshot.lifeosServerModified ?? [:]
        var failedItems = Set<String>(), failedDeletes = Set<String>(), failedCollections = Set<String>(), failedCollectionDeletes = Set<String>()
        var conflicts: [Record] = []
        func attempt(_ body: () async throws -> Void, failed: () -> Void) async throws {
            do { try await body() }
            catch let error as NativeRequestRejected where !error.message.contains("Operazione non disponibile") { return }
            catch let error as NativeRequestRejected { throw error }
            catch { failed() }
        }
        for id in snapshot.lifeosPendingCollections ?? [] {
            guard let c = snapshot.collections.first(where: { $0.text("id") == id }) else { continue }
            try await attempt({ _ = try await read("saveBloomCollection", [.object(c)]) }, failed: { failedCollections.insert(id) })
        }
        for id in snapshot.lifeosPendingItems ?? [] {
            guard let item = snapshot.items.first(where: { $0.text("id") == id }) else { continue }
            var body = Self.payload(item)
            if let known = modified[id] { body["expectModifiedAt"] = .number(known) }
            try await attempt({
                var result = try await read("saveBloomItem", [.object(body)]).object
                if result.flag("conflict") {
                    let current = result.record("current")
                    // The most recent edit wins: the device edit time against the site's.
                    if Self.unix(item.amount("modifiedAt")) > current.amount("modifiedAt") {
                        body.removeValue(forKey: "expectModifiedAt")
                        result = try await read("saveBloomItem", [.object(body)]).object
                    } else { conflicts.append(current); return }
                }
                if result.amount("modifiedAt") > 0 { modified[id] = result.amount("modifiedAt") }
            }, failed: { failedItems.insert(id) })
        }
        for id in snapshot.lifeosDeletedItems ?? [] {
            try await attempt({
                _ = try await read("trashBloomItem", [.string(id), .bool(true)])
                _ = try await read("deleteBloomItem", [.string(id)])
                modified.removeValue(forKey: id)
            }, failed: { failedDeletes.insert(id) })
        }
        for id in snapshot.lifeosDeletedCollections ?? [] {
            try await attempt({ _ = try await read("deleteBloomCollection", [.string(id)]) }, failed: { failedCollectionDeletes.insert(id) })
        }
        var next = bloom.archive
        // Keep only what failed, plus anything changed while sending.
        func keep(_ current: [String]?, _ sent: [String]?, _ failed: Set<String>) -> [String] {
            let sentSet = Set(sent ?? [])
            return (current ?? []).filter { !sentSet.contains($0) || failed.contains($0) }
        }
        let changedWhileSending = Set(next.items.filter { item in snapshot.items.first { $0.text("id") == item.text("id") } != item }.map { $0.text("id") })
        next.lifeosPendingItems = keep(next.lifeosPendingItems, snapshot.lifeosPendingItems, failedItems.union(changedWhileSending))
        next.lifeosDeletedItems = keep(next.lifeosDeletedItems, snapshot.lifeosDeletedItems, failedDeletes)
        next.lifeosPendingCollections = keep(next.lifeosPendingCollections, snapshot.lifeosPendingCollections, failedCollections)
        next.lifeosDeletedCollections = keep(next.lifeosDeletedCollections, snapshot.lifeosDeletedCollections, failedCollectionDeletes)
        // A more recent site edit replaces the device copy.
        for current in conflicts where !current.text("id").isEmpty {
            let id = current.text("id")
            let local = next.items.first { $0.text("id") == id }
            next.items.removeAll { $0.text("id") == id }
            next.items.append(Self.note(current, local: local))
            modified[id] = current.amount("modifiedAt")
        }
        next.lifeosServerModified = modified
        try bloom.applyServer(next)
    }

    private func readBloom(_ read: Reader) async throws {
        let value = try await read("getBloom", []).object
        var next = bloom.archive
        let pending = Set(next.lifeosPendingItems ?? []).union(next.lifeosDeletedItems ?? [])
        let pendingCollections = Set(next.lifeosPendingCollections ?? []).union(next.lifeosDeletedCollections ?? [])
        var modified = next.lifeosServerModified ?? [:]
        let local = Dictionary(next.items.map { ($0.text("id"), $0) }, uniquingKeysWith: { a, _ in a })
        var items: [Record] = []
        for row in value.records("items") {
            let id = row.text("id")
            guard !id.isEmpty else { continue }
            if pending.contains(id) { if let mine = local[id] { items.append(mine) }; continue }
            let stamp = row.amount("modifiedAt")
            if let mine = local[id], modified[id] == stamp { items.append(mine); continue }
            var full = row
            if row.integer("bodyLength") > 300 || row.text("notes").count >= 300 {
                full = (try? await read("getBloomItem", [.string(id)]).object) ?? row
            }
            items.append(Self.note(full, local: local[id]))
            modified[id] = stamp
        }
        // Notes still waiting to be sent stay; anything else missing was removed on the site.
        for id in pending where !items.contains(where: { $0.text("id") == id }) { if let mine = local[id], !(next.lifeosDeletedItems ?? []).contains(id) { items.append(mine) } }
        var collections = value.records("collections").map { row -> Record in
            var c = row.record("doc"); c["id"] = .string(row.text("id")); c["name"] = .string(row.text("name"))
            if case .number(let created)? = c["createdAt"] { c["createdAt"] = .number(Self.reference(created)) } else { c["createdAt"] = .number(0) }
            c.removeValue(forKey: "modifiedAt")
            return c
        }.filter { !pendingCollections.contains($0.text("id")) }
        collections += next.collections.filter { pendingCollections.contains($0.text("id")) && !(next.lifeosDeletedCollections ?? []).contains($0.text("id")) }
        let serverIDs = Set(value.records("items").map { $0.text("id") })
        for id in modified.keys where !serverIDs.contains(id) { modified.removeValue(forKey: id) }
        next.items = items; next.collections = collections; next.lifeosServerModified = modified
        try bloom.applyServer(next)
    }

    /// One file with everything the user owns on the device and the server copy of
    /// Bloom and foods; the permanent "Esporta backup completo" in Impostazioni.
    func fullBackup(app: Data?) throws -> Data {
        var out: Record = ["format": .string("LifeOS"), "version": .int(93), "createdAt": .string(ISO8601DateFormatter().string(from: Date()))]
        out["bloom"] = try JSONDecoder().decode(JSONValue.self, from: bloom.export())
        out["personalFoods"] = .array(try localFoods().map(appJSON))
        if let app, let value = try? JSONDecoder().decode(JSONValue.self, from: app) { out["app"] = value }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(JSONValue.object(out))
    }
}
