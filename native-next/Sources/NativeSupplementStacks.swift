import AppIntents
import SwiftUI

/// SUPPLEMENT-STACK-2026-11-23: a named set of supplements with their doses, recorded with one tap.
/// Kept on the server («supplement-stacks», shared with the site; the newest copy wins) with a local copy.
struct NativeSupplementStack: Codable, Identifiable, Equatable, Hashable {
    struct Item: Codable, Equatable, Hashable { var foodID: String; var name: String; var quantity: Double }
    var id: String
    var name: String
    var items: [Item]
}

@MainActor final class NativeSupplementStackStore: ObservableObject {
    static let shared = NativeSupplementStackStore()
    private static let key = "native-supplement-stacks-95", modifiedKey = "native-supplement-stacks-modified-95"
    @Published private(set) var stacks: [NativeSupplementStack] = []
    private let defaults = UserDefaults.standard
    private init() {
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode([NativeSupplementStack].self, from: data) { stacks = saved }
    }
    private var modified: Double { defaults.double(forKey: Self.modifiedKey) }

    func save(_ stack: NativeSupplementStack) { var next = stacks.filter { $0.id != stack.id }; next.append(stack); store(next.sorted { $0.name < $1.name }) }
    func delete(_ id: String) { store(stacks.filter { $0.id != id }) }
    private func store(_ next: [NativeSupplementStack], modified: Double = Date().timeIntervalSince1970 * 1000) {
        stacks = next
        if let data = try? JSONEncoder().encode(next) { defaults.set(data, forKey: Self.key) }
        defaults.set(modified, forKey: Self.modifiedKey)
        pendingPush = true
    }
    private var pendingPush = false

    /// Newest copy wins between this iPhone and the site (same rule as the goals).
    func sync(_ read: (String, [JSONValue]) async throws -> JSONValue) async {
        guard let remote = try? await read("getSettings", [.string("supplement-stacks")]).object else { return }
        let remoteModified = remote.amount("modified")
        if remoteModified > modified, let data = try? JSONEncoder().encode(remote.record("doc")["stacks"] ?? .array([])),
           let decoded = try? JSONDecoder().decode([NativeSupplementStack].self, from: data) {
            stacks = decoded
            if let local = try? JSONEncoder().encode(decoded) { defaults.set(local, forKey: Self.key) }
            defaults.set(remoteModified, forKey: Self.modifiedKey)
            pendingPush = false
        } else if modified > remoteModified || pendingPush, modified > 0,
                  let data = try? JSONEncoder().encode(["stacks": stacks]), let doc = try? JSONDecoder().decode(JSONValue.self, from: data) {
            if (try? await read("saveSettings", [.string("supplement-stacks"), doc, .number(modified)])) != nil { pendingPush = false }
        }
    }

    /// Supplements the user can put in a stack: catalog supplements and personal ones.
    static func supplements() -> [NativeGenericFood] {
        let data = UserDefaults.standard.data(forKey: "lifeos-personal-foods-v1") ?? Data()
        let personal = data.isEmpty ? [] : (try? JSONDecoder().decode([NativeGenericFood].self, from: data)) ?? []
        return NativeFoodPicker.items(in: .supplements, personal: personal)
    }

    /// Entries of a stack on a day (one per supplement; missing supplements are skipped).
    static func entries(_ stack: NativeSupplementStack, date: Date, foods: [NativeGenericFood] = supplements()) -> [NativeNutritionEntry] {
        stack.items.compactMap { item in
            guard item.quantity > 0, let food = foods.first(where: { $0.id == item.foodID }) else { return nil }
            return food.portion(id: UUID(), date: date, grams: Decimal(item.quantity))
        }
    }

    /// Records the whole stack; returns how many supplements were saved.
    func record(_ stack: NativeSupplementStack, date: Date = .now) async -> Int {
        let nutrition = NativeNutritionUIFixture.current
        var saved = 0
        for entry in Self.entries(stack, date: date) { if await nutrition.save(entry) { saved += 1 } }
        return saved
    }
}

/// The row of stacks at the top of «Aggiungi alimento»: one tap records a stack; «Nuova stack» opens the editor.
struct NativeSupplementStackStrip: View {
    @ObservedObject private var stacks = NativeSupplementStackStore.shared
    var date: Date = .now
    var onRecorded: (String) -> Void = { _ in }
    @State private var editing: NativeSupplementStack?
    @State private var working = false
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NativeDesign.Space.small) {
                ForEach(stacks.stacks) { stack in
                    Button {
                        working = true
                        Task {
                            let saved = await stacks.record(stack, date: date)
                            working = false
                            onRecorded(stack.name + " · " + String(saved) + (saved == 1 ? " integratore" : " integratori"))
                        }
                    } label: {
                        Label(stack.name, systemImage: "pills.fill").font(.subheadline.weight(.semibold))
                            .padding(.horizontal, NativeDesign.Space.medium).frame(minHeight: NativeDesign.Layout.compactControl)
                            .modifier(NativeGlass()).frame(minHeight: NativeDesign.Layout.touchTarget)
                    }
                    .buttonStyle(NativePressStyle())
                    .disabled(working)
                    .contextMenu {
                        Button("Modifica", systemImage: "pencil") { editing = stack }
                        Button("Elimina", systemImage: "trash", role: .destructive) { stacks.delete(stack.id) }
                    }
                    .accessibilityHint("Registra tutti gli integratori della stack")
                    .accessibilityIdentifier("supplement-stack-" + stack.id)
                }
                Button { editing = NativeSupplementStack(id: UUID().uuidString, name: "", items: []) } label: {
                    Label("Nuova stack", systemImage: "plus").font(.subheadline)
                        .padding(.horizontal, NativeDesign.Space.medium).frame(minHeight: NativeDesign.Layout.compactControl)
                        .modifier(NativeGlass()).frame(minHeight: NativeDesign.Layout.touchTarget)
                }
                .buttonStyle(NativePressStyle())
                .accessibilityIdentifier("supplement-stack-new")
            }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
        }
        .sheet(item: $editing) { stack in NavigationStack { NativeSupplementStackEditor(stack: stack) } }
    }
}

/// Name and doses: every supplement you have, with its dose (0 = not in the stack).
struct NativeSupplementStackEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var stack: NativeSupplementStack
    @State private var doses: [String: String] = [:]
    private let foods = NativeSupplementStackStore.supplements()
    var body: some View {
        Form {
            Section { TextField("es. Stack mattina", text: $stack.name).accessibilityIdentifier("supplement-stack-name") }
            Section("Integratori e dose") {
                ForEach(foods) { food in
                    LabeledContent(food.name) {
                        HStack(spacing: NativeDesign.Space.xs) {
                            TextField("0", text: Binding(get: { doses[food.id] ?? "" }, set: { doses[food.id] = $0 }))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: NativeDesign.Layout.actionCircle)
                                .accessibilityIdentifier("supplement-stack-dose-" + food.id)
                            Text(food.quantityUnit.isMassOrVolume ? (food.quantityUnit == .millilitre ? "ml" : "g") : food.quantityUnit.quantityTitle.lowercased())
                                .font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                    }
                }
                if foods.isEmpty { Text("Crea prima i tuoi integratori in Aggiungi alimento › Integratori.").foregroundStyle(NativeDesign.secondary) }
            }
        }
        .navigationTitle(stack.name.isEmpty ? "Nuova stack" : stack.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { NativeSheetCancel { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                NativeSheetConfirm {
                    stack.items = foods.compactMap { food in
                        guard let value = Double((doses[food.id] ?? "").replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
                        return .init(foodID: food.id, name: food.name, quantity: value)
                    }
                    NativeSupplementStackStore.shared.save(stack); dismiss()
                }
                .disabled(stack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !doses.values.contains { (Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 })
                .accessibilityIdentifier("supplement-stack-save")
            }
        }
        .onAppear { for item in stack.items { doses[item.foodID] = NSDecimalNumber(value: item.quantity).stringValue } }
    }
}

// MARK: Siri and Shortcuts

struct NativeStackEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Stack di integratori"
    static var defaultQuery = NativeStackQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct NativeStackQuery: EntityQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [NativeStackEntity] {
        NativeSupplementStackStore.shared.stacks.filter { identifiers.contains($0.id) }.map { .init(id: $0.id, name: $0.name) }
    }
    @MainActor func suggestedEntities() async throws -> [NativeStackEntity] {
        NativeSupplementStackStore.shared.stacks.map { .init(id: $0.id, name: $0.name) }
    }
}
struct RecordSupplementStackIntent: AppIntent {
    static var title: LocalizedStringResource = "Registra stack di integratori"
    static var description = IntentDescription("Registra in Life OS tutti gli integratori di una stack, con le loro dosi.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Stack") var stack: NativeStackEntity
    static var parameterSummary: some ParameterSummary { Summary("Registra \(\.$stack)") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let value = NativeSupplementStackStore.shared.stacks.first(where: { $0.id == stack.id }) else { throw Message(text: "Stack non trovata.") }
        let saved = await NativeSupplementStackStore.shared.record(value)
        guard saved > 0 else { throw Message(text: "Nessun integratore registrato. Apri Life OS e riprova.") }
        return .result(dialog: "Registrati \(saved) integratori di \(value.name).")
    }
}
/// «Ripeti l'ultimo alimento»: the most recent food again, now.
struct RepeatLastFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Ripeti l’ultimo alimento"
    static var description = IntentDescription("Registra di nuovo, adesso, l’ultimo alimento inserito in Life OS.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let nutrition = NativeNutritionUIFixture.current
        guard let last = nutrition.entries.filter({ $0.confirmed && $0.deletionPending != true && $0.foodName?.isEmpty == false }).max(by: { $0.date < $1.date }) else {
            throw Message(text: "Nessun alimento da ripetere.")
        }
        guard await nutrition.save(last.repeated(on: .now)) else { throw Message(text: "Non riuscito. Apri Life OS e riprova.") }
        return .result(dialog: "\(last.foodName ?? "Alimento") registrato di nuovo.")
    }
}
