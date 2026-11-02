import AppIntents
import Foundation

/// App and foreground intents share one store; never create a competing archive writer.
@MainActor enum NativeServices { static let store = NativeStore()
    static let health = NativeHealthStore() }

struct RecordWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Registra peso"
    static var description = IntentDescription("Salva il peso di oggi in Apple Health, con il tuo consenso.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Peso in kg", requestValueDialog: "Quanto pesi in chilogrammi?") var kilograms: Double
    static var parameterSummary: some ParameterSummary { Summary("Registra \(\.$kilograms) kg") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let health = NativeServices.health
        await health.start(demo: false)
        try await health.waitUntilIdle()
        try await health.saveWeight(kilograms, at: Date(), requestID: UUID())
        return .result(dialog: "Peso salvato in Apple Health.")
    }
}
struct PrepareTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Prepara attività"
    static var description = IntentDescription("Apre una nuova attività in Life OS con il titolo dettato. Premi Salva nell’app per confermare.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Titolo", requestValueDialog: "Quale attività vuoi preparare?") var taskTitle: String
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let clean = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 300 else { throw Message(text: "Scegli un titolo da 1 a 300 caratteri.") }
        NativeIntentDraft.taskTitle = clean
        NotificationCenter.default.post(name: .lifeOSRoute, object: URL(string: "lifeos://task")!)
        return .result(dialog: "Attività preparata. Premi Salva in Life OS per confermare.")
    }
}
@MainActor enum NativeIntentDraft { static var taskTitle: String?
    static var pendingURL: URL? }
struct LifeOSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordWeightIntent(), phrases: ["Registra il peso in \(.applicationName)"], shortTitle: "Registra peso", systemImageName: "scalemass")
        AppShortcut(intent: SaveBloomLinkIntent(), phrases: ["Salva un link in \(.applicationName)"], shortTitle: "Salva link", systemImageName: "books.vertical")
        AppShortcut(intent: PrepareTaskIntent(), phrases: ["Prepara un’attività in \(.applicationName)"], shortTitle: "Prepara attività", systemImageName: "checklist")
    }
}

struct SaveBloomLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Salva link in Bloom"
    static var description = IntentDescription("Conserva un link nella Libreria Bloom di LifeOS.")
    static var openAppWhenRun = true
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    @Parameter(title: "Link") var url: URL
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw Message(text: "Scegli un link web HTTP o HTTPS.") }
        let row: Record = ["id": .string(UUID().uuidString), "kind": .string("link"), "capturedAt": .number(Date().timeIntervalSinceReferenceDate), "urlString": .string(url.absoluteString), "archived": .bool(false), "title": .string(url.host ?? url.absoluteString), "noteVersion": .int(1)]
        try NativeBloomCaptureInbox.shared.capture(row, in: NativeBloomStore.shared)
        let destination = URL(string: "lifeos://bloom")!
        NativeIntentDraft.pendingURL = destination
        NotificationCenter.default.post(name: .lifeOSRoute, object: destination)
        return .result(dialog: "Link salvato nella Libreria Bloom.")
    }
}
