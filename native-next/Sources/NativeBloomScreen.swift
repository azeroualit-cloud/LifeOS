import SwiftUI
import MapKit
import UniformTypeIdentifiers
import QuickLook
import PhotosUI

private struct NativeBloomDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct NativeBloomScreen: View {
    @EnvironmentObject private var router: NativeRouter
    @StateObject private var store = NativeBloomStore.shared
    @State private var captureRecord: Record = [:]
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
    @State private var showingReport = false
    @State private var showTrash = false
    @State private var category = ""
    @State private var composing = false
    @AppStorage("lifeos.bloom.rediscovery.round") private var rediscoveryRound = 0
    @AppStorage("lifeos.bloom.filter.category") private var savedCategory = ""
    @State private var selectedPlaceNote: String?
    @State private var mapFitRequest = 0
    private var notes: [Record] {
        store.archive.items.filter { item in
            item.flag("archived") == showTrash && (category.isEmpty || (item["tagIDs"]?.array.map(\.string) ?? [item.text("collectionID")]).contains(category)) && (search.isEmpty || [item.text("title"), item.text("text"), item.text("notes"), item.text("urlString")].joined(separator: " ").localizedCaseInsensitiveContains(search))
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
            ZStack {
                NativeBloomClusteredPlacesMap(places: mapAnnotations, selectedID: selectedPlaceNote, fitRequest: mapFitRequest) { selectedPlaceNote = $0 }
                    .opacity(section == "Mappa" ? 1 : 0).allowsHitTesting(section == "Mappa").accessibilityHidden(section != "Mappa")
                if section != "Mappa" {
                List {
                    if section == "Libreria" {
                        Picker("Categoria", selection: $category) {
                            Text("Tutte le note").tag("")
                            ForEach(store.archive.collections.map { DisplayRecord($0, key: "id") }) { row in Text(row.value.text("name")).tag(row.value.text("id")) }
                        }
                    }
                    if section == "Riscopri" { Button("Nuovo giro") { rediscoveryRound += 1 }
                        Button("Vai alla libreria") { section = "Libreria" } }
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
            }
        }.navigationTitle("Bloom")
            .navigationDestination(isPresented: Binding(get: { selectedPlaceNote != nil }, set: { if !$0 { selectedPlaceNote = nil } })) {
                if let id = selectedPlaceNote { NativeBloomDetail(store: store, id: id) }
            }
            .onAppear { category = savedCategory }
            .onChange(of: router.bloomCaptureURL, initial: true) { _, raw in
                guard let raw else { return }
                captureRecord = ["id": .string(UUID().uuidString), "kind": .string("link"), "urlString": .string(raw), "title": .string(URL(string: raw)?.host ?? raw), "archived": .bool(false), "capturedAt": .number(Date().timeIntervalSinceReferenceDate), "noteVersion": .int(1)]
                router.bloomCaptureURL = nil; composing = true
            }
            .onChange(of: category) { _, value in savedCategory = value }
            .onChange(of: section) { _, value in if value == "Riscopri" { showTrash = false } }
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button("Nuova nota", systemImage: "plus") { captureRecord = [:]; composing = true } }
                ToolbarItem(placement: .secondaryAction) {
                    Menu("Archivio", systemImage: "ellipsis") {
                        Button(showTrash ? "Mostra Libreria" : "Cestino") { showTrash.toggle() }
                        Button("Importa backup Bloom") { importing = true }
                        Button("Ultimo rapporto importazione") { showingReport = true }.disabled(store.archive.lifeosImportReports?.isEmpty != false)
                        Button("Esporta backup") { do { exportData = try store.export(); exporting = true } catch { store.error = error.localizedDescription } }
                    }
                }
            }
            .sheet(isPresented: $showingReport) {
                NavigationStack {
                    Form {
                        if let report = store.archive.lifeosImportReports?.last {
                            LabeledContent("Data", value: report.date.formatted())
                            LabeledContent("Aggiunte", value: String(report.added))
                            LabeledContent("Già presenti o mantenute", value: String(report.skipped))
                            LabeledContent("Conflitti risolti", value: String(report.resolvedConflicts))
                            LabeledContent("Allegati", value: String(report.fileCount ?? 0))
                            LabeledContent("Byte", value: String(report.byteCount ?? 0))
                            Text(report.sourceSHA256 ?? "").font(.caption).textSelection(.enabled)
                            ForEach((report.categoryMappings ?? [:]).keys.sorted(), id: \.self) { source in
                                Text(source + " → " + (report.categoryMappings?[source] ?? "")).font(.caption)
                            }
                        }
                    }.navigationTitle("Rapporto importazione").toolbar { Button("Fine") { showingReport = false } }
                }
            }
            .sheet(isPresented: $composing) { NavigationStack { NativeBloomComposer(store: store, initial: captureRecord) } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(), access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 100 * 1024 * 1024 else { throw Message(text: "Backup superiore a 100 MiB.") }
                    let data = try Data(contentsOf: url), preview = try store.preview(data)
                    let files = preview.items.flatMap { item -> [Record] in (item["data"] != nil && item["data"] != .null ? [item] : []) + item.records("noteFiles") }
                    let bytes = files.reduce(0) { $0 + (Data(base64Encoded: $1.text("data"))?.count ?? 0) }
                    let trashed = preview.items.filter { $0.flag("archived") }.count
                    pendingSummary = "\(preview.items.count) note, \(preview.collections.count) categorie, \(files.count) allegati (\(bytes) byte), \(trashed) note nel Cestino. Il Cestino viene conservato."
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
    private var mapAnnotations: [NativeBloomPlaceMapAnnotation] {
        notes.compactMap { row in
            guard let bytes = try? JSONEncoder().encode(row.record("place")), let place = try? JSONDecoder().decode(NativeBloomPlace.self, from: bytes), place.isValid else { return nil }
            return NativeBloomPlaceMapAnnotation(id: row.text("id"), place: place, count: 1)
        }
    }
    private var ordered: [Record] {
        guard section == "Riscopri" else { return notes }
        let candidates = notes.compactMap { item -> NativeBloomRediscoveryCandidate? in
            guard let id = UUID(uuidString: item.text("id")) else { return nil }
            return .init(id: id, kind: item.text("kind"), collectionID: UUID(uuidString: item.text("collectionID")), host: URL(string: item.text("urlString"))?.host, isArchived: item.flag("archived"))
        }
        let day = CivilDate.calendar.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let ids = NativeBloomRediscoveryPlanner.select(candidates, day: day, round: rediscoveryRound)
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.text("id").lowercased(), $0) })
        return ids.compactMap { byID[$0.uuidString.lowercased()] }
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
                if item.text("kind") == "image", let hydrated = try? store.hydrated(item), let bytes = Data(base64Encoded: hydrated.text("data")) {
                    NativeBloomFramedImage(data: bytes, framing: item.record("imageFraming"))
                }
                NativeBloomMarkdownDocumentView(text: item.text("text", fallback: item.text("notes")))
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
                ForEach(Array(item.records("noteFiles").enumerated()), id: \.offset) { index, attachment in
                    Button("Apri " + attachment.text("name", fallback: "allegato")) { openAttachment(index) }
                }
                ForEach(Array((item["noteLinks"]?.array ?? []).enumerated()), id: \.offset) { _, value in
                    if let url = URL(string: value.string), ["http", "https"].contains(url.scheme ?? "") { Link(value.string, destination: url) }
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
            .quickLookPreview($file)
    }
    private func openAttachment(_ index: Int) {
        do {
            let attachments = try store.hydrated(item).records("noteFiles")
            guard attachments.indices.contains(index), let bytes = Data(base64Encoded: attachments[index].text("data")) else { throw Message(text: "Allegato non disponibile.") }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = URL(fileURLWithPath: attachments[index].text("name", fallback: "allegato")).lastPathComponent
            let path = directory.appendingPathComponent(name); try bytes.write(to: path); file = path
        } catch { store.error = error.localizedDescription }
    }
}

private struct NativeBloomComposer: View {
    @ObservedObject var store: NativeBloomStore
    var initial: Record = [:]
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var link = ""
    @State private var otherLinks: [JSONValue] = []
    @State private var readFailed = false
    @State private var didLoad = false
    @State private var tags = Set<String>()
    @State private var pinned = Set<String>()
    @State private var categoryName = ""
    @State private var placeRecord: Record?
    @State private var placeKind = "other"
    @State private var placeQuery = ""
    @State private var placeResults: [MKMapItem] = []
    @State private var searchingPlaces = false
    @State private var attachments: [Record] = []
    @State private var importing = false
    @State private var photo: PhotosPickerItem?
    @State private var primaryImage: Data?
    @State private var primaryFraming = NativeBloomImageFraming().record
    @State private var error: String?
    var body: some View {
        Form {
            TextField("Titolo", text: $title).accessibilityIdentifier("bloom-note-title")
            TextEditor(text: $text).accessibilityIdentifier("bloom-note-text").frame(minHeight: NativeDesign.Layout.activityDescriptionHeight)
            TextField("Link web", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            placeSection
            categorySection
            if let primaryImage { NavigationLink("Inquadratura immagine principale") { NativeBloomFramingEditor(data: primaryImage, framing: $primaryFraming) } }
            attachmentsSection
            if let error { Text(error).foregroundStyle(.red) }
        }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
                do {
                    let urls = try result.get()
                    guard attachments.count + urls.count <= 10 else { throw Message(text: "Massimo 10 allegati per nota.") }
                    var next = attachments
                    for url in urls {
                        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 25 * 1024 * 1024 else { throw Message(text: "File superiore a 25 MiB.") }
                        let bytes = try Data(contentsOf: url)
                        next.append(["id": .string(UUID().uuidString), "name": .string(url.lastPathComponent), "type": .string(UTType(filenameExtension: url.pathExtension)?.identifier ?? UTType.data.identifier), "data": .string(bytes.base64EncodedString())])
                    }
                    attachments = next
                } catch { self.error = error.localizedDescription }
            }
            .onChange(of: photo) { _, selected in
                Task {
                    do {
                        guard let selected, let bytes = try await selected.loadTransferable(type: Data.self) else { return }
                        guard bytes.count <= 25 * 1024 * 1024, attachments.count < 10 else { throw Message(text: "Limite allegati superato.") }
                        let type = selected.supportedContentTypes.first ?? .image
                        attachments.append(["id": .string(UUID().uuidString), "name": .string("Foto." + (type.preferredFilenameExtension ?? "jpg")), "type": .string(type.identifier), "data": .string(bytes.base64EncodedString())])
                    } catch { self.error = error.localizedDescription }
                }
            }
            .navigationTitle(initial.isEmpty ? "Nuova nota" : "Modifica nota")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") {
                    var item = initial
                    if item.isEmpty { item = ["id": .string(UUID().uuidString), "kind": .string("text"), "urlString": .string(""), "capturedAt": .number(Date().timeIntervalSinceReferenceDate), "archived": .bool(false), "noteVersion": .int(1)] }
                    if !link.isEmpty {
                        guard let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { error = "Inserisci un link HTTP o HTTPS valido."; return }
                        if item.text("kind") == "link" { item["urlString"] = .string(link) }
                        else { item["noteLinks"] = .array([.string(link)] + otherLinks) }
                    } else if item.text("kind") != "link" { item["noteLinks"] = .array(otherLinks) }
                    if primaryImage != nil { item["imageFraming"] = .object(primaryFraming) }
                    if var place = placeRecord { place["kind"] = .string(placeKind); item["place"] = .object(place) } else { item["place"] = .null }
                    item["tagIDs"] = .array(tags.sorted().map(JSONValue.string))
                    item["pinnedCategoryIDs"] = .array(pinned.intersection(tags).sorted().map(JSONValue.string))
                    item["collectionID"] = tags.sorted().first.map(JSONValue.string) ?? .null
                    item["noteFiles"] = .array(attachments.map(JSONValue.object))
                    item["title"] = .string(title); item[item.text("kind") == "text" ? "text" : "notes"] = .string(text); item["modifiedAt"] = .number(Date().timeIntervalSinceReferenceDate)
                    do { try store.save(item); dismiss() } catch { store.error = error.localizedDescription }
                }.disabled(readFailed || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && link.isEmpty && attachments.isEmpty) }
            }.onAppear {
                guard !didLoad else { return }; didLoad = true
                title = initial.text("title"); text = initial.text("text", fallback: initial.text("notes"))
                link = initial.text("urlString", fallback: initial["noteLinks"]?.array.first?.string ?? "")
                placeRecord = initial.record("place").isEmpty ? nil : initial.record("place")
                placeKind = initial.record("place").text("kind", fallback: "other")
                tags = Set(initial["tagIDs"]?.array.map(\.string) ?? (initial.text("collectionID").isEmpty ? [] : [initial.text("collectionID")]))
                pinned = Set(initial["pinnedCategoryIDs"]?.array.map(\.string) ?? [])
                otherLinks = Array((initial["noteLinks"]?.array ?? []).dropFirst())
                do {
                    let hydrated = try store.hydrated(initial); attachments = hydrated.records("noteFiles")
                    if initial.text("kind") == "image" { primaryImage = Data(base64Encoded: hydrated.text("data")); primaryFraming = initial.record("imageFraming").isEmpty ? NativeBloomImageFraming().record : initial.record("imageFraming") }
                } catch { readFailed = true; self.error = error.localizedDescription }
            }
    }
    private var placeSection: some View {
            Section("Luogo") {
                if let placeRecord {
                    Text(placeRecord.text("name"))
                    Picker("Tipologia", selection: $placeKind) {
                        ForEach(NativeBloomPlaceKind.allCases) { kind in Text(kind.label).tag(kind.rawValue) }
                        if NativeBloomPlaceKind(rawValue: placeKind) == nil { Text("Altro luogo").tag(placeKind) }
                    }
                    Button("Rimuovi luogo", role: .destructive) { self.placeRecord = nil }
                }
                TextField("Cerca con Apple Maps", text: $placeQuery)
                Button("Cerca luogo") {
                    let query = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    searchingPlaces = true
                    Task {
                        defer { searchingPlaces = false }
                        do {
                            let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
                            let response = try await MKLocalSearch(request: request).start()
                            if query == placeQuery.trimmingCharacters(in: .whitespacesAndNewlines) { placeResults = response.mapItems }
                        } catch { self.error = error.localizedDescription }
                    }
                }.disabled(searchingPlaces || placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if searchingPlaces { ProgressView("Ricerca") }
                ForEach(Array(placeResults.enumerated()), id: \.offset) { _, result in
                    Button(result.name ?? "Luogo") {
                        placeRecord = ["name": .string(result.name ?? "Luogo"), "latitude": .number(result.placemark.coordinate.latitude), "longitude": .number(result.placemark.coordinate.longitude)]
                        placeKind = "other"; placeResults = []
                    }
                }
            }
    }
    private var categorySection: some View {
            Section("Categorie") {
                ForEach(store.archive.collections.map { DisplayRecord($0, key: "id") }) { row in
                    let id = row.value.text("id")
                    Toggle(row.value.text("name"), isOn: Binding(get: { tags.contains(id) }, set: { value in if value { tags.insert(id) } else { tags.remove(id); pinned.remove(id) } }))
                    if tags.contains(id) {
                        Toggle("Fissa in " + row.value.text("name"), isOn: Binding(get: { pinned.contains(id) }, set: { value in if value { pinned.insert(id) } else { pinned.remove(id) } }))
                    }
                }
                TextField("Nuova categoria", text: $categoryName)
                Button("Crea categoria") { do { tags.insert(try store.addCategory(categoryName)); categoryName = "" } catch { self.error = error.localizedDescription } }.disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
    }
    private var attachmentsSection: some View {
            Section("Allegati") {
                ForEach(Array(attachments.enumerated()), id: \.offset) { index, attachment in
                    HStack { Text(attachment.text("name")); Spacer(); Button("Rimuovi", role: .destructive) { attachments.remove(at: index) } }
                    if UTType(attachment.text("type"))?.conforms(to: .image) == true, let bytes = Data(base64Encoded: attachment.text("data")) {
                        NavigationLink("Inquadratura " + attachment.text("name")) {
                            NativeBloomFramingEditor(data: bytes, framing: Binding(get: { attachments.indices.contains(index) ? attachments[index].record("framing") : NativeBloomImageFraming().record }, set: { value in if attachments.indices.contains(index) { attachments[index]["framing"] = .object(value) } }))
                        }
                    }
                }
                Button("Aggiungi file") { importing = true }.disabled(attachments.count >= 10)
                PhotosPicker("Aggiungi foto", selection: $photo, matching: .images).disabled(attachments.count >= 10)
            }
    }

}
