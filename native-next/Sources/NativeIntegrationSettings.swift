import SwiftUI
import AppIntents
import UserNotifications

struct NativeIntegrationSettings: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.scenePhase) private var phase
    @AppStorage("native-reminders-enabled") private var enabled = false
    @State private var status = "Verifica in corso…"
    @State private var requesting = false
    var body: some View {
        Section("Notifiche e Siri") {
            Toggle("Promemoria locali", isOn: Binding(get: { enabled }, set: { value in
                if !value { enabled = false; return }
                requesting = true
                Task {
                    defer { requesting = false }
                    do { enabled = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]); await refreshStatus() }
                    catch { status = error.localizedDescription }
                }
            })).disabled(requesting || store.isDemo)
            Text(status).font(.caption).foregroundStyle(NativeDesign.secondary)
            Text("Attività all’orario scelto (altrimenti alle 9 del giorno programmato o della scadenza), eventi 15 minuti prima, turni un’ora prima. Sono programmati i prossimi 48 avvisi dai dati presenti su questo iPhone. Apri l’app dopo modifiche dal web per aggiornarli.").font(.caption).foregroundStyle(NativeDesign.secondary)
            if let url = URL(string: UIApplication.openSettingsURLString) { Link("Impostazioni notifiche di iPhone", destination: url) }
            ShortcutsLink()
            Text("Con Siri: “Registra il peso in Life OS” oppure “Prepara un’attività in Life OS”. Il peso viene scritto in Apple Health dopo il consenso. Per le attività conferma il salvataggio nell’app.").font(.caption).foregroundStyle(NativeDesign.secondary)
            Text("Widget: aggiungi “Life OS · Azioni rapide” alla schermata Home. Apre attività, peso e calendario. La disponibilità va verificata dopo la firma Signulous.").font(.caption).foregroundStyle(NativeDesign.secondary)
        }.task { await refreshStatus() }
        .onChange(of: phase) { _, value in if value == .active { Task { await refreshStatus() } } }
    }
    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: status = enabled ? "Notifiche autorizzate su questo iPhone." : "Promemoria disattivati nell’app."
        case .denied: status = "Notifiche negate: puoi abilitarle nelle impostazioni di iPhone."
        case .notDetermined: status = "Attiva i promemoria per autorizzare le notifiche."
        @unknown default: status = "Controlla le impostazioni notifiche di iPhone."
        }
        if let error = NativeNotifications.shared.lastError { status = error }
    }
}
