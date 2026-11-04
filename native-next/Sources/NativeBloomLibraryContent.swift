import SwiftUI
import ImageIO

struct NativeBloomThumbnail: View {
    let url: URL?
    var width: CGFloat? = nil
    @State private var image: UIImage?
    var body: some View {
        Group { if let image { Image(uiImage: image).resizable().scaledToFit().frame(width: width).clipped().accessibilityHidden(true) } else { Image(systemName: "photo").foregroundStyle(.secondary).accessibilityLabel("Anteprima immagine non disponibile") } }
            .task(id: url) {
                guard let url else { image = nil; return }
                let result = await Task.detached(priority: .utility) {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return Optional<UIImage>.none }
                    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 384]
                    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
                    return UIImage(cgImage: thumbnail)
                }.value
                guard !Task.isCancelled else { return }; image = result
            }
    }
}

struct NativeBloomLibraryContent: View {
    @ObservedObject var store: NativeBloomStore
    let notes: [Record]
    @Binding var category: String
    let showTrash: Bool
    let rediscovery: Bool
    let newRound: () -> Void
    let goToLibrary: () -> Void
    @AppStorage("lifeos.bloom.library.grid") private var grid = true
    @State private var selecting = false
    @State private var selected = Set<String>()
    @State private var showingCategories = false
    var body: some View {
        VStack(spacing: NativeDesign.Space.small) {
            if !rediscovery {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    Picker("Categoria", selection: $category) {
                        Text("Tutte le note").tag("")
                        ForEach(store.archive.collections.map { NativeBloomRow($0) }) { row in Text(row.value.text("name")).tag(row.value.text("id")) }
                    }.pickerStyle(.menu).labelsHidden().lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                    HStack {
                        Button(grid ? "Elenco" : "Griglia", systemImage: grid ? "list.bullet" : "square.grid.2x2") { grid.toggle() }.labelStyle(.iconOnly)
                            .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
                        Button(selecting ? "Fine" : "Seleziona") { selecting.toggle(); selected = [] }.frame(minHeight: NativeDesign.Layout.touchTarget)
                        Spacer()
                        Button("Categorie", systemImage: "folder") { showingCategories = true }.labelStyle(.iconOnly)
                            .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
                    }
                }.padding(.horizontal)
            } else {
                HStack { Button("Nuovo giro", action: newRound); Spacer(); Button("Vai alla libreria", action: goToLibrary) }.padding(.horizontal)
            }
            if selecting {
                HStack {
                    Text("\(selected.count) selezionate").font(.caption)
                    Menu("Categoria") {
                        ForEach(store.archive.collections.map { NativeBloomRow($0) }) { row in
                            Button(row.value.text("name")) { perform { try store.updateNotes(selected, category: row.value.text("id")) } }
                        }
                    }.disabled(selected.isEmpty)
                    Button(showTrash ? "Ripristina" : "Cestino") { perform { try store.updateNotes(selected, archived: !showTrash) } }.disabled(selected.isEmpty)
                }.padding(.horizontal)
            }
            if notes.isEmpty { ContentUnavailableView("Nessuna nota", systemImage: "books.vertical", description: Text("Aggiungi una nota o importa un backup Bloom.")) }
            else if grid || rediscovery {
                GeometryReader { geometry in
                    let inset = NativeDesign.Space.large
                    let gap = NativeDesign.Space.medium
                    let width = max(1, (geometry.size.width - inset * 2 - gap) / 2)
                    ScrollView {
                        HStack(alignment: .top, spacing: gap) {
                            ForEach(0..<2, id: \.self) { column in
                                LazyVStack(spacing: gap) {
                                    ForEach(Array(notes.enumerated()).filter { $0.offset % 2 == column }.map { NativeBloomRow($0.element) }) { item in
                                        destination(item.value, width: width)
                                    }
                                }.frame(width: width, alignment: .topLeading)
                            }
                        }.padding(.horizontal, inset).padding(.bottom, NativeDesign.Layout.scrollClearance)
                    }.accessibilityIdentifier("bloom-library-scroll")
                }
            } else {
                List {
                    ForEach(notes.map { NativeBloomRow($0) }) { item in
                        destination(item.value, width: nil).swipeActions {
                            Button(showTrash ? "Ripristina" : "Cestino", role: showTrash ? nil : .destructive) { perform { try store.trash(item.value, restore: showTrash) } }
                        }
                    }
                }
            }
        }.sheet(isPresented: $showingCategories) { NavigationStack { NativeBloomCategories(store: store) } }
            .onChange(of: notes.map { $0.text("id") }) { _, ids in selected.formIntersection(ids) }
    }
    @ViewBuilder private func destination(_ row: Record, width: CGFloat?) -> some View {
        if selecting {
            Button { let id = row.text("id"); if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } } label: {
                card(row, width: width).overlay(alignment: .topTrailing) { Image(systemName: selected.contains(row.text("id")) ? "checkmark.circle.fill" : "circle").padding(NativeDesign.Space.small) }
            }.buttonStyle(.plain)
        } else { NavigationLink { NativeBloomDetail(store: store, id: row.text("id")) } label: { card(row, width: width) }.buttonStyle(.plain)
            .accessibilityIdentifier("bloom-note-" + row.text("id"))
            .accessibilityLabel(NativeBloomRow(row).displayTitle) }
    }
    private func card(_ row: Record, width: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            if let url = store.primaryFileURL(row) { NativeBloomThumbnail(url: url, width: width.map { max(1, $0 - NativeDesign.Space.medium * 2) }).clipped() }
            if let link = NativeBloomRow(row).previewURL {
                NativeBloomLinkPreview(url: link, width: max(1, (width ?? NativeDesign.Layout.bloomGridMinimum) - NativeDesign.Space.medium * 2), showTitle: row.text("title").isEmpty)
            }
            if NativeBloomRow(row).previewURL == nil || !row.text("title").isEmpty {
                Text(NativeBloomRow(row).displayTitle).font(.headline).lineLimit(3).multilineTextAlignment(.leading)
            }
            if !row.text("text").isEmpty { Text(row.text("text")).font(.subheadline).foregroundStyle(.secondary).lineLimit(4).multilineTextAlignment(.leading) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(NativeDesign.Space.medium)
            .frame(width: width, alignment: .leading).clipped()
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
            .contentShape(Rectangle())
    }
    private func perform(_ operation: () throws -> Void) { do { try operation(); selected = [] } catch { store.error = error.localizedDescription } }
}

private struct NativeBloomCategories: View {
    @ObservedObject var store: NativeBloomStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var editing: String?
    @State private var deleting: String?
    var body: some View {
        Form {
            Section(editing == nil ? "Nuova categoria" : "Rinomina categoria") {
                TextField("Nome", text: $name)
                Button("Salva") {
                    do { if let editing { try store.renameCategory(editing, name: name) } else { _ = try store.addCategory(name) }; editing = nil; name = "" }
                    catch { store.error = error.localizedDescription }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Categorie") {
                ForEach(store.archive.collections.map { NativeBloomRow($0) }) { row in
                    let members = store.archive.items.filter { !$0.flag("archived") && ($0["tagIDs"]?.array.map(\.string) ?? [$0.text("collectionID")]).contains(row.value.text("id")) }
                    HStack {
                        ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { _, member in
                            if let url = store.primaryFileURL(member) { NativeBloomThumbnail(url: url).frame(width: NativeDesign.Layout.iconTile, height: NativeDesign.Layout.iconTile).clipped() }
                        }
                        Button(row.value.text("name") + " (\(members.count))") { editing = row.value.text("id"); name = row.value.text("name") }
                    }.swipeActions { Button("Elimina", role: .destructive) { deleting = row.value.text("id") } }
                }
            }
            if let error = store.error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Categorie").toolbar { Button("Fine") { dismiss() } }
            .confirmationDialog("Eliminare la categoria? Le note vengono conservate nella Libreria.", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Elimina categoria", role: .destructive) { guard let deleting else { return }; do { try store.removeCategory(deleting); self.deleting = nil } catch { store.error = error.localizedDescription } }
            }
    }
}
