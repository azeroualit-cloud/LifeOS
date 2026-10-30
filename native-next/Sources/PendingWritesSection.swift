import SwiftUI

struct PendingWritesSection: View {
    @EnvironmentObject var store: NativeStore
    @State private var discarding: PendingWrite?
    private func title(_ write: PendingWrite) -> String {
        switch write.method {
        case "saveActivity": return write.payload.text("title", fallback: "Attività")
        case "setTaskStatus": return "Stato attività"
        case "setEventOccurrence": return "Evento del " + write.payload.text("day")
        case "setRoutineCheck": return "Abitudine del " + write.payload.text("day")
        case "paintShift": return "Turno del " + write.payload.text("day")
        case "saveHealthEntry": return "Misurazione del " + write.payload.text("day")
        default: return "Movimento finanziario"
        }
    }
    var body: some View {
        Section("Modifiche sul dispositivo") {
            Text(store.syncStatus.isEmpty ? "In attesa di sincronizzazione" : store.syncStatus).font(.caption)
            ForEach(store.state.pending) { write in
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    Text(title(write))
                    Text(write.accepted ? "Ricevuta dal server · aggiornamento dati in attesa" : "Conferma del server in attesa").font(.caption).foregroundStyle(NativeDesign.secondary)
                    if !write.accepted && write.payload.integer("expenseRoutingVersion") == 1 {
                        Button("Annulla invio non ancora iniziato", role: .destructive) { Task { do { try await store.cancelPendingExpense(write.id) } catch { store.error = error.localizedDescription } } }.disabled(store.busy || store.syncing)
                    }
                    if !write.accepted && LocalLifeMutation.supports(write.method) {
                        Button("Annulla modifica locale", role: .destructive) { discarding = write }.disabled(store.busy || store.syncing)
                    }
                }
            }
            Button("Riprova sincronizzazione") { Task { await store.sync() } }.disabled(store.busy || store.syncing)
        }.confirmationDialog("Ripristinare il valore presente sul server? È necessaria la rete. Un invio già ricevuto dal server non verrà annullato.", isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } })) {
            if let write = discarding {
                Button("Ripristina dal server", role: .destructive) { Task { do { try await store.discardLocalWrite(write.id) } catch { store.error = error.localizedDescription }; discarding = nil } }
            }
        }
    }
}
