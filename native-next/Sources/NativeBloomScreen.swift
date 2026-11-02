import SwiftUI
import MapKit
import UniformTypeIdentifiers

private struct NativeBloomDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct NativeBloomScreen: View {
    @StateObject private var store = NativeBloomStore()
    @State private var section = "Libreria"
    @State private var search = ""
    @State private var importing = false
    @State private var exporting = false
    @State private var exportData = Data()
    @State private var pendingData: Data?
    @State private var pendingSummary = ""
    @State private var importConflicts: [NativeBloomConflict] = []
    @State private var resolutions: [String: NativeBloomConflictChoice] = [:]
    @State private var notice: String?
    @State private var showTrash = false
    @State private var composing = false
    @State private var shuffled: [String] = []
    @State private var position: MapCameraPosition = .automatic
    private var notes: [Record] {
        store.archive.items.filter { item in
            item.flag("archived") == showTrash && (search.isEmpty || [item.text("title"), item.text("text"), item.text("notes"), item.text("urlString")].joined(separator: " ").localizedCaseInsensitiveContains(search))
        }.sorted { $0.amount("capturedAt") > $1.amount("capturedAt") }
    }
    var body: some View {
        VStack {
            Picker("Sezione Bloom", selection: $section) {
                Label("Libreria", systemImage: "books.vertical").tag("Libreria")
                Label("Mappa", systemImage: "map").tag("Mappa")
                Label("Riscopri", systemImage: "sparkles").tag("Riscopri")
            }.pickerStyle(.segmented).padding(.horizontal)
            if let notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if let error = store.error { Text(error).foregroundStyle(.red) }
            if section == "Mappa" {
                Map(position: $position) {
                    ForEach(notes.map { DisplayRecord($0, key: "id") }) { item in
                        let place = item.value.record("place")
                        if let latitude = place["latitude"]?.number, let longitude = place["longitude"]?.number, latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) {
                            Annotation(place.text("name"), coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                                NavigationLink { NativeBloomDetail(store: store, id: item.value.text("id")) } label: { Image(systemName: "mappin.circle.fill").font(.title).accessibilityLabel(place.text("name")) }
                            }
                        }
                    }
                }
            } else {
                List {
                    if section == "Riscopri" { Button("Nuovo giro") { shuffled = notes.map { $0.text("id") }.shuffled() } }
                    ForEach(ordered.map { DisplayRecord($0, key: "id") }) { item in
                        NavigationLink { NativeBloomDetail(store: store, id: item.value.text("id")) } label: {
                            VStack(alignment: .leading) {
                                Text(title(item.value)).font(.headline)
                                if !item.value.text("text").isEmpty { Text(item.value.text("text")).lineLimit(3).foregroundStyle(.secondary) }
                            }
                        }.swipeActions {
                            Button(showTrash ? "Ripristina" : "Cestino", role: showTrash ? nil : .destructive) { do { try store.trash(item.value, restore: showTrash) } catch { store.error = error.localizedDescription } }
                        }
                    }
                }.searchable(text: $search, prompt: "Cerca nella Libreria")
            }
        }.navigationTitle("Bloom")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button("Nuova nota", systemImage: "plus") { composing = true } }
                ToolbarItem(placement: .secondaryAction) {
                    Menu("Archivio", systemImage: "ellipsis") {
                        Button(showTrash ? "Mostra Libreria" : "Cestino") { showTrash.toggle() }
                        Button("Importa backup Bloom") { importing = true }
                        Button("Esporta backup") { do { exportData = try store.export(); exporting = true } catch { store.error = error.localizedDescription } }
                    }
                }
            }
            .sheet(isPresented: $composing) { NavigationStack { NativeBloomComposer(store: store) } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(), access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 100 * 1024 * 1024 else { throw Message(text: "Backup superiore a 100 MiB.") }
                    let data = try Data(contentsOf: url), preview = try store.preview(data)
                    pendingSummary = "\(preview.items.count) note e \(preview.collections.count) categorie. Le note nel Cestino saranno conservate."
                    importConflicts = try store.conflicts(data); resolutions = [:]
                    pendingData = data
                } catch { store.error = error.localizedDescription }
            }
            .sheet(isPresented: Binding(get: { pendingData != nil }, set: { if !$0 { pendingData = nil } })) {
                NavigationStack {
                    Form {
                        Section { Text(pendingSummary) }
                        ForEach(importConflicts) { conflict in
                            Section(conflict.title) {
                                Picker("Conflitto", selection: Binding(get: { resolutions[conflict.id]?.rawValue ?? "" }, set: { resolutions[conflict.id] = NativeBloomConflictChoice(rawValue: $0) })) {
                                    Text("Scegli una soluzione").tag("")
                                    Text("Mantieni LifeOS").tag("keep")
                                    Text("Sostituisci dal backup").tag("replace")
                                    Text("Conserva una copia").tag("copy")
                                }
                            }
                        }
                        Button("Importa") {
                            guard let data = pendingData else { return }
                            do { notice = try store.importBackup(data, resolutions: resolutions); pendingData = nil }
                            catch { store.error = error.localizedDescription }
                        }.disabled(importConflicts.contains { resolutions[$0.id] == nil })
                        if let error = store.error { Text(error).foregroundStyle(.red) }
                    }.navigationTitle("Importa backup")
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { pendingData = nil } } }
                }
            }
            .fileExporter(isPresented: $exporting, document: NativeBloomDocument(data: exportData), contentType: .json, defaultFilename: "LifeOS-Bloom-backup") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
    }
    private var ordered: [Record] {
        guard section == "Riscopri", !shuffled.isEmpty else { return notes }
        let order = Dictionary(uniqueKeysWithValues: shuffled.enumerated().map { ($0.element, $0.offset) })
        return notes.sorted { (order[$0.text("id")] ?? Int.max) < (order[$1.text("id")] ?? Int.max) }
    }
    private func title(_ item: Record) -> String { item.text("title", fallback: item.text("fileName", fallback: String(item.text("text", fallback: item.text("urlString", fallback: "Nota")).prefix(80)))) }
}

private struct NativeBloomDetail: View {
    @ObservedObject var store: NativeBloomStore
    let id: String
    @State private var editing = false
    @State private var file: URL?
    private var item: Record { store.archive.items.first { $0.text("id") == id } ?? [:] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                Text(item.text("title")).font(.title)
                Text(LocalizedStringKey(item.text("text", fallback: item.text("notes")))).textSelection(.enabled)
                if let url = URL(string: item.text("urlString")), ["https", "http"].contains(url.scheme ?? "") { Link(item.text("urlString"), destination: url) }
                if !item.text("lifeosFileSHA256").isEmpty {
                    Button("Apri " + item.text("fileName", fallback: "allegato")) {
                        do {
                            let hydrated = try store.hydrated(item)
                            guard let bytes = Data(base64Encoded: hydrated.text("data")) else { return }
                            let name = URL(fileURLWithPath: item.text("fileName", fallback: "allegato")).lastPathComponent
                            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                            let path = directory.appendingPathComponent(name); try bytes.write(to: path); file = path
                        } catch { store.error = error.localizedDescription }
                    }
                }
                let place = item.record("place")
                if !place.isEmpty {
                    Text(place.text("name"))
                    Button("Apri in Mappe") {
                        let point = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: place.amount("latitude"), longitude: place.amount("longitude"))))
                        point.name = place.text("name"); point.openInMaps()
                    }
                }
            }.padding()
        }.navigationTitle("Nota").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Modifica") { editing = true } }
            .sheet(isPresented: $editing) { NavigationStack { NativeBloomComposer(store: store, initial: item) } }
            .sheet(isPresented: Binding(get: { file != nil }, set: { if !$0 { file = nil } })) { if let file { ShareLink("Condividi allegato", item: file).padding() } }
    }
}

private struct NativeBloomComposer: View {
    @ObservedObject var store: NativeBloomStore
    var initial: Record = [:]
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    var body: some View {
        Form { TextField("Titolo", text: $title); TextEditor(text: $text).frame(minHeight: NativeDesign.Layout.activityDescriptionHeight) }
            .navigationTitle(initial.isEmpty ? "Nuova nota" : "Modifica nota")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") {
                    var item = initial
                    if item.isEmpty { item = ["id": .string(UUID().uuidString), "kind": .string("text"), "urlString": .string(""), "capturedAt": .number(Date().timeIntervalSinceReferenceDate), "archived": .bool(false), "noteVersion": .int(1)] }
                    item["title"] = .string(title); item[item.text("kind") == "text" ? "text" : "notes"] = .string(text); item["modifiedAt"] = .number(Date().timeIntervalSinceReferenceDate)
                    do { try store.save(item); dismiss() } catch { store.error = error.localizedDescription }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.onAppear { title = initial.text("title"); text = initial.text("text", fallback: initial.text("notes")) }
    }
}
