import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct NativeSettings: View {
    @EnvironmentObject var store: NativeStore
    @AppStorage("native-theme") private var theme = "system"
    @State private var endpoint = ""
    @State private var testConfirmed = false
    @State private var importing = false
    @State private var login = false
    @State private var exporting = false
    @State private var backup: JSONDocument?
    @State private var message: String?
    @State private var useDemo = false
    @ObservedObject private var online = NativeOnlineSync.shared
    var body: some View {
        Form {
            Section("Dati") {
                NavigationLink { NativeOnlineDataScreen() } label: {
                    LabeledContent("Dati sul server", value: online.online ? (online.lastError == nil ? "Sincronizzati" : "Da riprovare") : "Sul telefono")
                }.accessibilityIdentifier("settings-online-data")
                Button("Esporta backup completo") {
                    do { backup = JSONDocument(data: try online.fullBackup(app: try store.backupData())); exporting = true } catch { message = error.localizedDescription }
                }.accessibilityIdentifier("settings-full-backup")
            }
            Section("Aspetto") {
                Picker("Tema", selection: $theme) { Text("Automatico").tag("system"); Text("Chiaro").tag("light"); Text("Scuro").tag("dark") }
            }
            NativeIntegrationSettings()
            if !store.state.pending.isEmpty { PendingWritesSection() }
            Section("Modalità") {
                LabeledContent("Attuale", value: store.isDemo ? "Demo locale" : store.server == nil ? "Snapshot locale" : store.sharedDatabase ? "Condiviso con il sito" : "Server collegato")
                Button("Apri demo completa") { useDemo = true }.disabled(store.busy)
                if store.isDemo && store.hasSavedConnection { Button("Torna ai dati precedenti") { do { try store.restoreConnection(); message = "Dati e coda precedenti ripristinati." } catch { message = error.localizedDescription } }.disabled(store.busy) }
            }
            Section("Connessione Life OS") {
                TextField("https://lifeos-native-test.a-zeroual-it.workers.dev", text: $endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Toggle("Confermo l’indirizzo del mio server Life OS", isOn: $testConfirmed)
                Button("Collega") { do { try store.configure(endpoint); message = "Server configurato. Accedi e sincronizza." } catch { message = error.localizedDescription } }.disabled(!testConfirmed || store.busy)
                if store.server != nil {
                    Button("Accedi") { login = true }
                    Button("Sincronizza") { Task { await store.sync(); message = store.error ?? store.notice ?? "Aggiornamento completato." } }.disabled(store.busy)
                }
                Link("Apri Life OS sul web", destination: URL(string: "https://lifeos.a-zeroual-it.workers.dev/")!)
            }
            Section("Importazione") {
                Button("Importa snapshot JSON") { message = nil; importing = true }.disabled(store.server != nil || store.busy)
                NavigationLink("Incolla JSON") { PasteJSONScreen() }.disabled(store.server != nil || store.busy)
            }
            if let message { Section { Text(message).font(.callout).textSelection(.enabled) } }
            if let notice = store.notice { Section { Text(notice).font(.caption).foregroundStyle(NativeDesign.secondary) } }
            Section("Life OS") {
                LabeledContent("Versione", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3")
                LabeledContent("Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
                LabeledContent("Modifiche da sincronizzare", value: String(store.state.pending.count))
            }
        }.modifier(NativeListAppearance()).navigationTitle("Impostazioni").toolbar { DoneButton() }
        .onAppear { endpoint = store.state.endpoint ?? ""; testConfirmed = store.server != nil }
        .confirmationDialog("Aprire la demo con dati simulati? I dati attuali verranno conservati separatamente.", isPresented: $useDemo, titleVisibility: .visible) {
            Button("Apri demo") { do { try store.useDemo(); endpoint = ""; message = "Demo pronta. Puoi tornare ai dati precedenti da queste impostazioni." } catch { message = error.localizedDescription } }
        }
        .fullScreenCover(isPresented: $importing) {
            SnapshotDocumentPicker { result in
                importing = false
                switch result {
                case .success(let data): do { try store.importFinance(data); message = "Snapshot importato correttamente." } catch { message = error.localizedDescription }
                case .failure(let error): message = error.localizedDescription
                }
            } onCancel: { importing = false }
        }
        .sheet(isPresented: $login) {
            NavigationStack {
                NativeSignInScreen {
                    login = false
                    Task { await store.sync() }
                }
            }
        }
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "LifeOS-backup-" + CivilDate.day()) { result in
            switch result { case .success: message = "Backup esportato."; case .failure(let error): message = error.localizedDescription }
        }
    }
}

// UIKit owns selection and returns a copied file; no SwiftUI fileImporter layered over another sheet.
struct SnapshotDocumentPicker: UIViewControllerRepresentable {
    let onResult: (Result<Data, Error>) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Some Files providers expose JSON as generic data. Validate bytes, not provider metadata.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false; picker.shouldShowFileExtensions = true; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onResult: (Result<Data, Error>) -> Void
        let onCancel: () -> Void
        init(onResult: @escaping (Result<Data, Error>) -> Void, onCancel: @escaping () -> Void) { self.onResult = onResult; self.onCancel = onCancel }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onCancel() }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { onResult(.failure(Message(text: "Nessun file selezionato."))); return }
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var result: Result<Data, Error> = .failure(Message(text: "Il file non è disponibile sul dispositivo."))
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                result = Result {
                    let attributes = try FileManager.default.attributesOfItem(atPath: readable.path)
                    guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 5_000_000 else { throw Message(text: "Il file è troppo grande.") }
                    return try Data(contentsOf: readable)
                }
            }
            if let coordinationError { onResult(.failure(coordinationError)) } else { onResult(result) }
        }
    }
}
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct PasteJSONScreen: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var message: String?
    var body: some View {
        Form {
            Section("Contenuto dello snapshot") { TextEditor(text: $text).font(.system(.caption, design: .monospaced)).frame(minHeight: 250).autocorrectionDisabled().textInputAutocapitalization(.never) }
            Button("Importa") { do { try store.importFinance(Data(text.utf8)); dismiss() } catch { message = error.localizedDescription } }.disabled(text.isEmpty)
            if let message { Text(message).foregroundStyle(NativeDesign.danger) }
        }.modifier(NativeListAppearance()).navigationTitle("Incolla JSON")
    }
}

/// Where Bloom and personal foods live (BUILD93-REQUEST-2026-11-21).
struct NativeOnlineDataScreen: View {
    @ObservedObject private var online = NativeOnlineSync.shared
    @ObservedObject private var bloom = NativeBloomStore.shared
    @AppStorage(NativeOnlineSync.foodsKey) private var foods = Data()
    @EnvironmentObject var store: NativeStore
    private var waiting: Int { (bloom.archive.lifeosPendingItems ?? []).count + (bloom.archive.lifeosDeletedItems ?? []).count }
    private var foodCount: Int { (try? JSONDecoder().decode([NativeGenericFood].self, from: foods))?.count ?? 0 }
    private var attachmentBytes: Int {
        bloom.archive.items.reduce(0) { total, item in total + ([item] + item.records("noteFiles")).reduce(0) { $0 + $1.integer("lifeosFileBytes") } }
    }
    var body: some View {
        Form {
            Section("Fonte dei dati") {
                LabeledContent("Bloom", value: bloom.archive.lifeosTransferred93 == true ? "Server · \(bloom.archive.items.count)" : "Telefono · \(bloom.archive.items.count)")
                LabeledContent("Alimenti personali", value: (UserDefaults.standard.bool(forKey: NativeOnlineSync.foodsTransferredKey) ? "Server · " : "Telefono · ") + String(foodCount))
                if waiting > 0 { LabeledContent("In attesa di invio", value: String(waiting)) }
                if let last = online.lastSync { LabeledContent("Ultimo aggiornamento", value: last.formatted(date: .omitted, time: .shortened)) }
                if let error = online.lastError { Text(error).foregroundStyle(NativeDesign.danger) }
            }
            Section("Allegati di Bloom") {
                LabeledContent("Sul telefono", value: ByteCountFormatter.string(fromByteCount: Int64(attachmentBytes), countStyle: .file))
            }
            Section {
                Button("Aggiorna ora") { Task { await store.sync() } }.disabled(store.busy || store.server == nil)
                    .accessibilityIdentifier("online-data-refresh")
            }
        }.modifier(NativeListAppearance()).navigationTitle("Dati")
    }
}
