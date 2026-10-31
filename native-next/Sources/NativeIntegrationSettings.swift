import SwiftUI
import AppIntents
import UserNotifications
import WidgetKit

struct NativeIntegrationSettings: View {
    @EnvironmentObject var store: NativeStore
    @State private var widgetStatus = "Widget Life OS"
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
            NavigationLink { Form { ShiftCalendarPanel() }.modifier(NativeListAppearance()).navigationTitle("Esporta turni").navigationBarTitleDisplayMode(.inline) } label: {
                Label("Esporta turni su Apple", systemImage: "calendar.badge.plus")
            }.accessibilityIdentifier("shift-export-settings")
            ShortcutsLink()
            Text("Con Siri: “Registra il peso in Life OS” oppure “Prepara un’attività in Life OS”. Il peso viene scritto in Apple Health dopo il consenso. Per le attività conferma il salvataggio nell’app.").font(.caption).foregroundStyle(NativeDesign.secondary)
            Button("Aggiorna widget 2×2") {
                NativeWidgetBridge.publish(life: store.life, demo: store.isDemo, updatedAt: store.state.lifeRefreshedAt)
                Task { await refreshStatus() }
            }
            Text("Se nella galleria non compare ‘Life OS · Oggi’, la versione dell’estensione installata è ancora quella precedente: reinstalla l’IPA mantenendo l’estensione widget nel servizio di firma.").font(.caption).foregroundStyle(NativeDesign.secondary)
            Text(widgetStatus).font(.caption).foregroundStyle(NativeDesign.secondary)
        }.task { await refreshStatus() }
        .onChange(of: phase) { _, value in if value == .active { Task { await refreshStatus() } } }
    }
    private func refreshStatus() async {
        widgetStatus = NativeWidgetBridge.status
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
