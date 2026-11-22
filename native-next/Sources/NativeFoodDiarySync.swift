import Foundation

/// Shared food diary (FOOD-DIARY-SERVER-2026-11-22): meals are logged on the phone and can be
/// edited from the PC. The server keeps one row per meal; the most recent change wins and
/// deletions travel as tombstones. Weight stays in Apple Health only.
/// The phone sends its own changes, then applies the server's newer ones to Apple Health.
@MainActor final class NativeFoodDiarySync {
    static let shared = NativeFoodDiarySync()
    typealias Reader = NativeOnlineSync.Reader

    static let transferredKey = "lifeos-food-diary-transferred-93"
    static let pendingKey = "lifeos-food-diary-pending-93"
    static let cursorKey = "lifeos-food-diary-cursor-93"

    struct Change: Codable, Equatable { var id: String; var deleted: Bool; var modified: Double }

    private let defaults: UserDefaults
    private let store: NativeNutritionStore
    init(defaults: UserDefaults = .standard, store: NativeNutritionStore? = nil) {
        self.defaults = defaults
        self.store = store ?? .shared
    }

    /// Hooks the diary to the store: every local save or deletion is queued for the server.
    func connect(onChange: @escaping () -> Void) {
        store.onLocalChange = { [weak self] id in
            guard let self else { return }
            let entry = self.store.entries.first { $0.id == id }
            self.enqueue(.init(id: id.uuidString, deleted: entry == nil,
                               modified: Self.millis(entry?.modifiedAt ?? Date())))
            onChange()
        }
    }

    var pending: [Change] {
        get { defaults.data(forKey: Self.pendingKey).flatMap { try? JSONDecoder().decode([Change].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.pendingKey) }
    }
    func enqueue(_ change: Change) {
        var list = pending
        list.removeAll { $0.id == change.id }
        list.append(change)
        pending = list
    }

    // MARK: Mapping

    nonisolated static func millis(_ date: Date) -> Double { (date.timeIntervalSince1970 * 1000).rounded() }
    nonisolated static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
    nonisolated static func date(_ text: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }
    nonisolated static func number(_ value: Decimal?) -> JSONValue {
        guard let value else { return .null }
        return .number(NSDecimalNumber(decimal: value).doubleValue)
    }

    /// Local entry → server row: readable fields for the site plus the complete app entry.
    nonisolated static func row(_ entry: NativeNutritionEntry) throws -> Record {
        let app = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(entry))
        return [
            "id": .string(entry.id.uuidString),
            "at": .string(iso(entry.date)),
            "name": .string(entry.foodName ?? ""),
            "grams": number(entry.portionGrams),
            "ml": number(entry.portionMillilitres),
            "kcal": number(entry.calories),
            "protein": number(entry.protein),
            "carbs": number(entry.carbohydrate),
            "fat": number(entry.fat),
            "fibre": number(entry.fibre),
            "revision": .int(entry.revision),
            "modified": .number(millis(entry.modifiedAt ?? entry.date)),
            "app": app,
        ]
    }

    /// Server row → entry. The complete app entry is the base; the fields the site can edit
    /// (time, name, quantity, macros) come from the row. A meal added on the site has no app part.
    nonisolated static func entry(_ row: Record) -> NativeNutritionEntry? {
        guard let id = UUID(uuidString: row.text("id")), let at = date(row.text("at")) else { return nil }
        var base: NativeNutritionEntry
        let app = row.record("app")
        if !app.isEmpty, let data = try? JSONEncoder().encode(JSONValue.object(app)),
           let decoded = try? JSONDecoder().decode(NativeNutritionEntry.self, from: data), decoded.id == id {
            base = decoded
        } else {
            base = NativeNutritionEntry(id: id, revision: 0, date: at, protein: 0, carbohydrate: 0, fat: 0, confirmed: false)
        }
        func decimal(_ key: String) -> Decimal? {
            guard case .number(let value)? = row[key], value.isFinite, value >= 0 else { return nil }
            return Decimal(string: String(format: "%.3f", value), locale: Locale(identifier: "en_US_POSIX"))
        }
        base.date = at
        base.foodName = row.text("name").isEmpty ? base.foodName : row.text("name")
        if let grams = decimal("grams") { base.portionGrams = grams }
        if let ml = decimal("ml") { base.portionMillilitres = ml }
        base.protein = decimal("protein") ?? base.protein
        base.carbohydrate = decimal("carbs") ?? base.carbohydrate
        base.fat = decimal("fat") ?? base.fat
        base.fibre = decimal("fibre") ?? base.fibre
        if let kcal = decimal("kcal") { base.labelCalories = kcal }
        base.revision = max(base.revision, row.integer("revision"))
        base.modifiedAt = Date(timeIntervalSince1970: row.amount("modified") / 1000)
        base.confirmed = false
        base.deletionPending = nil
        return base
    }

    // MARK: Sync

    /// Sends local changes, then applies the server's newer ones. A Worker without the diary
    /// methods leaves everything on the phone unchanged.
    func sync(_ read: Reader) async throws {
        do { _ = try await read("listFoodDiary", [.number(Double.greatestFiniteMagnitude)]) }
        catch let error as NativeRequestRejected where error.message.contains("Operazione non disponibile") { return }

        if !defaults.bool(forKey: Self.transferredKey) {
            let rows = try store.entries.filter { $0.confirmed && $0.deletionPending != true }.map(Self.row)
            for start in stride(from: 0, to: rows.count, by: 200) {
                _ = try await read("importFoodDiary", [.array(rows[start..<min(rows.count, start + 200)].map(JSONValue.object))])
            }
            defaults.set(true, forKey: Self.transferredKey)
            pending = []
        }

        var remaining: [Change] = []
        for change in pending {
            do {
                if change.deleted {
                    _ = try await read("deleteFoodDiaryEntry", [.string(change.id), .number(change.modified)])
                } else if let entry = store.entries.first(where: { $0.id.uuidString == change.id && $0.confirmed }) {
                    let result = try await read("saveFoodDiaryEntry", [.object(try Self.row(entry))]).object
                    // A newer copy on the server wins: it is applied below with the other changes.
                    if !result.flag("saved") { defaults.set(0.0, forKey: Self.cursorKey) }
                }
            } catch let error as NativeRequestRejected where !error.message.contains("Operazione non disponibile") {
                continue // a rejected change is dropped; the server copy is read back below
            } catch { remaining.append(change) }
        }
        pending = remaining
        guard remaining.isEmpty else { return } // keep unsent edits until they reach the server

        let since = defaults.double(forKey: Self.cursorKey)
        let response = try await read("listFoodDiary", [.number(since)]).object
        var cursor = since
        for row in response.records("entries").sorted(by: { $0.amount("modified") < $1.amount("modified") }) {
            guard let id = UUID(uuidString: row.text("id")) else { cursor = max(cursor, row.amount("modified")); continue }
            let local = store.entries.first { $0.id == id }
            let localModified = local.map { Self.millis($0.modifiedAt ?? $0.date) } ?? 0
            if row.amount("modified") <= localModified { cursor = max(cursor, row.amount("modified")); continue }
            let applied: Bool
            if row.flag("deleted") { applied = await store.applyRemoteDeletion(id) }
            else if let entry = Self.entry(row) { applied = await store.applyRemote(entry) }
            else { applied = true }
            guard applied else { break } // retry from here at the next sync
            cursor = max(cursor, row.amount("modified"))
        }
        defaults.set(cursor, forKey: Self.cursorKey)
    }
}
