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
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var store = NativeBloomVisualFixture.store()
    @StateObject private var classifier = NativeBloomPlaceClassifier()
    @StateObject private var captureInbox = NativeBloomCaptureInbox.shared
    @State private var showingCaptures = false
    @State private var captureRecord: Record = [:]
    @State private var section = "Libreria"
    @State private var search = ""
    @State private var importing = false
    @State private var exporting = false
    @State private var exportData = Data()
    @State private var pickerHandoff = NativeBloomPickerHandoff()
    @State private var preparingImport = false
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
    @State private var hasOpenedMap = false
    @State private var hasOpenedRediscovery = false
    @State private var mapFitRequest = 0
    private var notes: [Record] {
        store.archive.items.filter { item in
            item.flag("archived") == showTrash && (category.isEmpty || (item["tagIDs"]?.array.map(\.string) ?? [item.text("collectionID")]).contains(category)) && (search.isEmpty || [item.text("title"), item.text("text"), item.text("notes"), item.text("urlString")].joined(separator: " ").localizedCaseInsensitiveContains(search))
        }.sorted {
            if !category.isEmpty {
                let left = $0["pinnedCategoryIDs"]?.array.map(\.string).contains(category) ?? false
                let right = $1["pinnedCategoryIDs"]?.array.map(\.string).contains(category) ?? false
                if left != right { return left }
            }
            return $0.amount("capturedAt") > $1.amount("capturedAt")
        }
    }
    var body: some View {
        VStack {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: NativeDesign.Space.small)) : AnyLayout(HStackLayout(spacing: NativeDesign.Space.small))
            layout {
                NativeBloomSectionButton(title: "Libreria", id: "library", selection: $section)
                NativeBloomSectionButton(title: "Mappa", id: "map", selection: $section)
            }.padding(.horizontal, NativeDesign.Layout.screenInset)
            if store.archive.items.isEmpty && section == "Libreria" {
                VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                    Text("Hai già contenuti in Bloom?").font(.headline)
                    Text("Importa il backup esportato dall’app Bloom. Note, raccolte e allegati verranno conservati su questo iPhone.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button { startImport() } label: {
                        Label("Importa backup Bloom", systemImage: "square.and.arrow.down")
                            .foregroundStyle(NativeDesign.onAccent)
                            .frame(minHeight: NativeDesign.Layout.touchTarget)
                    }.buttonStyle(NativeCompactPrimaryButtonStyle())
                        .frame(minHeight: NativeDesign.Layout.touchTarget)
                        .accessibilityIdentifier("bloom.importBackup")
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .padding(NativeDesign.Layout.screenInset)
            }
            if preparingImport { ProgressView("Preparazione backup…") }
            if let notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if section == "Mappa" {
                HStack {
                    Button("Inquadra luoghi") { mapFitRequest += 1 }
                    Button(classifier.running ? "Ricerca in corso" : "Classifica luoghi") { Task { await classifier.classify(in: store) } }.disabled(classifier.running)
                }.font(.subheadline)
                if let message = classifier.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            if let error = store.error { Text(error).foregroundStyle(.red) }
            ZStack {
                if hasOpenedMap {
                    NativeBloomClusteredPlacesMap(places: mapAnnotations, isVisible: section == "Mappa", selectedID: selectedPlaceNote, fitRequest: mapFitRequest) { selectedPlaceNote = $0 }
                        .opacity(section == "Mappa" ? 1 : 0).allowsHitTesting(section == "Mappa").accessibilityHidden(section != "Mappa")
                }
                NativeBloomLibraryContent(store: store, notes: notes, category: $category, showTrash: showTrash, rediscovery: false, newRound: { rediscoveryRound += 1 }, goToLibrary: { section = "Libreria" })
                    .opacity(section == "Libreria" ? 1 : 0).allowsHitTesting(section == "Libreria").accessibilityHidden(section != "Libreria")
                if hasOpenedRediscovery {
                    NativeBloomLibraryContent(store: store, notes: ordered, category: $category, showTrash: false, rediscovery: true, newRound: { rediscoveryRound += 1 }, goToLibrary: { section = "Libreria" })
                        .opacity(section == "Riscopri" ? 1 : 0).allowsHitTesting(section == "Riscopri").accessibilityHidden(section != "Riscopri")
                }
            }
        }.navigationTitle("Bloom")
            .modifier(NativeUITestValue(value: pickerHandoff.diagnostic + ";preparing=\(preparingImport);preview=\(pendingData != nil)", identifier: "bloom-import-state"))
            .searchable(text: $search, prompt: "Cerca nella Libreria")
            .navigationDestination(isPresented: Binding(get: { selectedPlaceNote != nil }, set: { if !$0 { selectedPlaceNote = nil } })) {
                if let id = selectedPlaceNote, let group = mapGroups.first(where: { $0.id == id }) {
                    List {
                        Section(group.place.name) {
                            ForEach(group.notes.map { NativeBloomRow($0) }) { row in
                                NavigationLink { NativeBloomDetail(store: store, id: row.value.text("id")) } label: { Text(row.displayTitle) }
                            }
                        }
                        Section { Button("Apri in Mappe") {
                            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: group.place.latitude, longitude: group.place.longitude)))
                            item.name = group.place.name; item.openInMaps()
                        } }
                    }.navigationTitle(group.place.name)
                }
            }
            .task { prepareImportFixture() }
            .onAppear { category = store.archive.collections.contains(where: { $0.text("id") == savedCategory }) ? savedCategory : "" }
            .onChange(of: store.archive.collections.map { $0.text("id") }) { _, ids in if !category.isEmpty && !ids.contains(category) { category = "" } }
            .onChange(of: router.bloomCaptureURL, initial: true) { _, raw in
                guard let raw else { return }
                captureRecord = ["id": .string(UUID().uuidString), "kind": .string("link"), "urlString": .string(raw), "title": .string(URL(string: raw)?.host ?? raw), "archived": .bool(false), "capturedAt": .number(Date().timeIntervalSinceReferenceDate), "noteVersion": .int(1)]
                router.bloomCaptureURL = nil; composing = true
            }
            .onChange(of: category) { _, value in savedCategory = value }
            .onChange(of: section) { _, value in
                if value == "Riscopri" { showTrash = false; hasOpenedRediscovery = true }
                if value == "Mappa" { hasOpenedMap = true }
            }
            .toolbar { bloomToolbar }
            .sheet(isPresented: $showingCaptures) { capturesSheet }
            .sheet(isPresented: $showingReport) { reportSheet }
            .sheet(isPresented: $composing) { NavigationStack { NativeBloomComposer(store: store, initial: captureRecord) } }
            .sheet(isPresented: $importing, onDismiss: {
                pickerHandoff.didDismiss(); prepareSelectedBackup()
            }) {
                NativeBloomBackupPicker(completion: { result in
                    switch result {
                    case .success(let data): pickerHandoff.picked(data)
                    case .failure(let error): store.error = error.localizedDescription
                    }
                    importing = false
                    prepareSelectedBackup()
                }, onCancel: { pickerHandoff.cancel(); importing = false })
            }
            .sheet(isPresented: Binding(get: { pendingData != nil }, set: { if !$0 { pendingData = nil } })) { importSheet }
            .fileExporter(isPresented: $exporting, document: NativeBloomDocument(data: exportData), contentType: .json, defaultFilename: "LifeOS-Bloom-backup") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
    }
    @ToolbarContentBuilder private var bloomToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { archiveMenu }.sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) { newNoteButton }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { archiveMenu }
            ToolbarItem(placement: .topBarTrailing) { newNoteButton }
        }
    }
    private var newNoteButton: some View {
        NativeToolbarButton(symbol: "plus", label: "Nuova nota") { captureRecord = [:]; composing = true }
    }
    private var archiveMenu: some View {
        Menu {
            Button(showTrash ? "Mostra Libreria" : "Cestino") { showTrash.toggle() }
            Button("Importa backup Bloom", action: startImport).accessibilityIdentifier("bloom-import-menu-item")
            Button("Catture da completare (\(captureInbox.requests.count))") { showingCaptures = true }
            Button("Ultimo rapporto importazione") { showingReport = true }.disabled(store.archive.lifeosImportReports?.isEmpty != false)
            Button("Esporta backup") { do { exportData = try store.export(); exporting = true } catch { store.error = error.localizedDescription } }
        } label: { NativeToolbarIcon(symbol: "ellipsis") }
            .buttonStyle(.plain).accessibilityLabel("Archivio").accessibilityIdentifier("bloom-archive-menu")
    }
    private func prepareImportFixture() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--bloom-import-fixture") else { return }
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let note: Record = ["id": .string("8A20F968-EF06-430B-86D4-41BB50A0D278"),
                "kind": .string("text"), "urlString": .string(""), "text": .string("Bloom import UI fixture"),
                "title": .string("Bloom import UI fixture"), "capturedAt": .number(100),
                "archived": .bool(false), "noteVersion": .int(1),
                "noteFiles": .array([.object(["id": .string("8E87EC90-775A-438D-AD69-F8978087F1CD"),
                    "name": .string("synthetic.bin"), "type": .string("public.data"),
                    "data": .string(Data(repeating: 42, count: 6 * 1024 * 1024).base64EncodedString())])])]
            try JSONEncoder().encode(NativeBloomArchive(items: [note])).write(to: directory.appendingPathComponent("Bloom-UI-Fixture.json"), options: .atomic)
            try Data("invalid JSON".utf8).write(to: directory.appendingPathComponent("Bloom-Invalid-Fixture.json"), options: .atomic)
        } catch { store.error = error.localizedDescription }
        #endif
    }
    private func startImport() {
        guard !preparingImport else { return }
        pickerHandoff.begin(); store.error = nil; importing = true
    }
    private func prepareSelectedBackup() {
        guard let data = pickerHandoff.takeReadyData() else { return }
        preparingImport = true
        // File picker has completed its dismissal before presenting the preview.
        Task { @MainActor in
            await Task.yield()
            defer { preparingImport = false }
            do {
                let preview = try await Task.detached(priority: .userInitiated) { try NativeBloomStore.validatedBackup(data) }.value
                let files = preview.items.flatMap { item -> [Record] in
                    (item["data"] != nil && item["data"] != .null ? [item] : []) + item.records("noteFiles")
                }
                let bytes = files.reduce(0) { $0 + (Data(base64Encoded: $1.text("data"))?.count ?? 0) }
                let trashed = preview.items.filter { $0.flag("archived") }.count
                pendingSummary = "\(preview.items.count) note, \(preview.collections.count) categorie, \(files.count) allegati (\(bytes) byte), \(trashed) note nel Cestino. Il Cestino viene conservato."
                importConflicts = try store.conflicts(data, validatedIncoming: preview); resolutions = [:]
                pendingData = data
            } catch { store.error = error.localizedDescription }
        }
    }
    private var capturesSheet: some View {
                NavigationStack {
                    List {
                        if let error = captureInbox.error { Text(error).foregroundStyle(.red) }
                        ForEach(captureInbox.requests) { request in
                            VStack(alignment: .leading) {
                                Text(request.row.text("urlString"))
                                Button("Riprova") { do { try captureInbox.retry(request, in: store) } catch { store.error = error.localizedDescription } }
                            }
                        }
                        if let error = store.error { Text(error).foregroundStyle(.red) }
                    }.navigationTitle("Catture in sospeso").toolbar { Button("Fine") { showingCaptures = false } }
                }
    }

    private var reportSheet: some View {
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

    private var importSheet: some View {
                NavigationStack {
                    Form {
                        Section { Text(pendingSummary) }
                        ForEach(importConflicts) { conflict in
                            Section(conflict.title) {
                                NavigationLink { NativeBloomConflictComparison(conflict: conflict) } label: {
                                    Label("Confronta versioni", systemImage: "doc.on.doc")
                                }
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
                            do { notice = try store.importBackup(data, resolutions: resolutions); category = ""; search = ""; showTrash = false; section = "Libreria"; pendingData = nil }
                            catch { store.error = error.localizedDescription }
                        }.disabled(importConflicts.contains { resolutions[$0.id] == nil })
                        if let error = store.error { Text(error).foregroundStyle(.red) }
                    }.navigationTitle("Importa backup")
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { pendingData = nil } } }
                }
    }
    private struct MapGroup: Identifiable {
        let id: String
        let place: NativeBloomPlace
        var notes: [Record]
    }
    private var mapGroups: [MapGroup] {
        var groups: [String: MapGroup] = [:]
        for row in notes {
            guard let bytes = try? JSONEncoder().encode(row.record("place")), let place = try? JSONDecoder().decode(NativeBloomPlace.self, from: bytes), place.isValid else { continue }
            let name = place.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT")).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(place.latitude):\(place.longitude):" + name
            if var group = groups[key] { group.notes.append(row); groups[key] = group }
            else { groups[key] = MapGroup(id: key, place: place, notes: [row]) }
        }
        return groups.values.sorted { $0.id < $1.id }
    }
    private var mapAnnotations: [NativeBloomPlaceMapAnnotation] {
        mapGroups.map { NativeBloomPlaceMapAnnotation(id: $0.id, place: $0.place, count: $0.notes.count) }
    }
    private var ordered: [Record] {
        let candidates = notes.compactMap { item -> NativeBloomRediscoveryCandidate? in
            guard let id = UUID(uuidString: item.text("id")) else { return nil }
            return .init(id: id, kind: item.text("kind"), collectionID: UUID(uuidString: item.text("collectionID")), host: URL(string: item.text("urlString"))?.host, isArchived: item.flag("archived"))
        }
        let day = CivilDate.calendar.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let ids = NativeBloomRediscoveryPlanner.select(candidates, day: day, round: rediscoveryRound)
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.text("id").lowercased(), $0) })
        return ids.compactMap { byID[$0.uuidString.lowercased()] }
    }

}

private struct NativeBloomSectionButton: View {
    let title: String
    let id: String
    @Binding var selection: String
    private var selected: Bool { selection == title }
    private var control: some View {
        Button { selection = title } label: {
            Text(title).font(.subheadline)
                .foregroundStyle(selected ? NativeDesign.onAccent : Color.primary)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget)
        }
    }
    var body: some View {
        styledControl
            .contentShape(.accessibility, Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityIdentifier("bloom-section-" + id)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selection = title }
    }
    @ViewBuilder private var styledControl: some View {
        if #available(iOS 26.0, *) {
            control.buttonStyle(NativePressStyle())
                .glassEffect(.regular.tint(selected ? NativeDesign.accent : .clear).interactive(), in: Capsule())
        } else {
            control.buttonStyle(NativePressStyle())
                .background(selected ? NativeDesign.accent : NativeDesign.surface, in: Capsule())
        }
    }
}

struct NativeBloomDetail: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: NativeBloomStore
    let id: String
    @State private var editing = false
    @State private var confirmingDeletion = false
    @State private var file: URL?
    private var item: Record { store.archive.items.first { $0.text("id") == id } ?? [:] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                Text(item.text("title")).font(.title)
                NativeBloomMediaPager(store: store, item: item, openFile: openRecord)
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
            .toolbar {
                Button("Modifica") { editing = true }
                if item.flag("archived") { Button("Elimina definitivamente", systemImage: "trash.slash", role: .destructive) { confirmingDeletion = true } }
                Button(item.flag("archived") ? "Ripristina" : "Sposta nel Cestino", systemImage: item.flag("archived") ? "arrow.uturn.backward" : "trash") {
                    do { try store.trash(item, restore: item.flag("archived")); dismiss() } catch { store.error = error.localizedDescription }
                }
            }
            .sheet(isPresented: $editing) { NavigationStack { NativeBloomComposer(store: store, initial: item) } }
            .quickLookPreview($file)
            .confirmationDialog("Eliminare definitivamente la nota dalla Libreria? Restano eventuali copie nei backup.", isPresented: $confirmingDeletion) {
                Button("Elimina definitivamente", role: .destructive) { do { try store.deleteArchivedNote(id); dismiss() } catch { store.error = error.localizedDescription } }
            }
    }
    private func openRecord(_ source: Record) {
        do {
            let hydrated = try store.hydrated(source)
            guard let bytes = Data(base64Encoded: hydrated.text("data")) else { throw Message(text: "Allegato non disponibile.") }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = URL(fileURLWithPath: source.text("fileName", fallback: source.text("name", fallback: "allegato"))).lastPathComponent
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
    @State private var loadingPhoto = false
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
                guard selected != nil else { return }
                loadingPhoto = true
                Task {
                    defer { loadingPhoto = false }
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
                }.disabled(readFailed || loadingPhoto || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && link.isEmpty && attachments.isEmpty && initial.text("lifeosFileSHA256").isEmpty) }
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
                ForEach(store.archive.collections.map { NativeBloomRow($0) }) { row in
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
                if loadingPhoto { ProgressView("Caricamento foto") }
                Button("Aggiungi file") { importing = true }.disabled(attachments.count >= 10 || loadingPhoto)
                PhotosPicker("Aggiungi foto", selection: $photo, matching: .images).disabled(attachments.count >= 10 || loadingPhoto)
            }
    }

}
