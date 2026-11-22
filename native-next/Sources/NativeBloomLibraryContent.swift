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

/// 60 pt square preview for list rows: the note's image, else the link's
/// preview image, else a neutral symbol.
struct NativeBloomRowThumbnail: View {
    let fileURL: URL?
    let linkURL: URL?
    @State private var linkImage: UIImage?
    var body: some View {
        ZStack {
            NativeDesign.inset
            if let fileURL {
                NativeBloomThumbnail(url: fileURL).scaledToFill()
            } else if let linkImage {
                Image(uiImage: linkImage).resizable().scaledToFill()
                    .accessibilityLabel("Anteprima link").accessibilityIdentifier("bloom-link-image")
            } else {
                Image(systemName: linkURL == nil ? "note.text" : "link").font(.headline).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
        .frame(width: NativeDesign.Layout.bloomRowThumbnail, height: NativeDesign.Layout.bloomRowThumbnail)
        .clipShape(RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous))
        .task(id: linkURL) {
            guard fileURL == nil, let linkURL else { linkImage = nil; return }
            let value = await NativeBloomLinkPreviews.shared.load(linkURL)
            guard !Task.isCancelled else { return }
            linkImage = value?.image.flatMap { UIImage(data: $0) }
        }
    }
}

struct NativeBloomLibraryContent: View {
    @ObservedObject var store: NativeBloomStore
    let notes: [Record]
    @Binding var category: String
    @Binding var filter: NativeBloomAutoFilter
    let filters: [NativeBloomAutoFilter]
    let showTrash: Bool
    let rediscovery: Bool
    let newRound: () -> Void
    let goToLibrary: () -> Void
    // Build 92: a list is the default (mockup approved), the grid stays one tap away.
    @AppStorage("lifeos.bloom.library.layout") private var layoutChoice = "list"
    @State private var selecting = false
    @State private var selected = Set<String>()
    @State private var showingCategories = false
    private var grid: Bool { layoutChoice == "grid" }
    private var categoryTitle: String {
        store.archive.collections.first { $0.text("id") == category }?.text("name") ?? "tutte"
    }
    var body: some View {
        VStack(spacing: NativeDesign.Space.small) {
            if !rediscovery {
                filterBar
                if selecting { selectionBar }
            } else {
                HStack { Button("Nuovo giro", action: newRound); Spacer(); Button("Vai alla libreria", action: goToLibrary) }.padding(.horizontal)
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
                ScrollView {
                    LazyVStack(spacing: NativeDesign.Space.none) {
                        ForEach(notes.map { NativeBloomRow($0) }) { item in
                            destination(item.value, width: nil)
                                .contextMenu {
                                    Button(showTrash ? "Ripristina" : "Sposta nel Cestino", systemImage: showTrash ? "arrow.uturn.backward" : "trash", role: showTrash ? nil : .destructive) {
                                        perform { try store.trash(item.value, restore: showTrash) }
                                    }
                                }
                            if item.id != notes.last?.text("id") { Divider().padding(.leading, NativeDesign.Layout.bloomListDivider) }
                        }
                    }
                    .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
                    .padding(.horizontal, NativeDesign.Layout.screenInset)
                    .padding(.bottom, NativeDesign.Layout.scrollClearance)
                }.accessibilityIdentifier("bloom-library-scroll")
            }
        }.sheet(isPresented: $showingCategories) { NavigationStack { NativeBloomCategories(store: store) } }
            .onChange(of: notes.map { $0.text("id") }) { _, ids in selected.formIntersection(ids) }
    }
    /// One row of glass pills: source and category open native menus
    /// (BLOOM-CATEGORIES-92); view and selection on the right.
    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: NativeDesign.Space.small) { sourcePill; categoryPill; Spacer(minLength: 0); viewTools }
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                HStack(spacing: NativeDesign.Space.small) { sourcePill; categoryPill }
                HStack { Spacer(minLength: 0); viewTools }
            }
        }
        .padding(.horizontal, NativeDesign.Layout.screenInset)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bloom-filters")
    }
    private var sourcePill: some View {
        LOFilterPill(title: "Fonte", value: filter == .all ? "tutte" : filter.title, isActive: filter != .all, identifier: "bloom-filter-source") {
            Picker("Fonte", selection: $filter) {
                ForEach(filters) { item in Text(item == .all ? "Tutte le fonti" : item.title).tag(item) }
            }
        }
    }
    private var categoryPill: some View {
        LOFilterPill(title: "Categoria", value: categoryTitle, isActive: !category.isEmpty, identifier: "bloom-filter-category") {
            Picker("Categoria", selection: $category) {
                Text("Tutte le categorie").tag("")
                ForEach(store.archive.collections.map { NativeBloomRow($0) }) { row in
                    let count = store.archive.items.filter { !$0.flag("archived") && NativeBloomRow.categories(of: $0).contains(row.id) }.count
                    Text(row.value.text("name") + " (\(count))").tag(row.id)
                }
            }
            Divider()
            Button("Gestisci categorie", systemImage: "folder.badge.gearshape") { showingCategories = true }
                .accessibilityIdentifier("bloom-manage-categories")
        }
    }
    private var viewTools: some View {
        HStack(spacing: NativeDesign.Space.xs) {
            Button { layoutChoice = grid ? "list" : "grid" } label: {
                Image(systemName: grid ? "list.bullet" : "square.grid.2x2")
                    .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
            }.accessibilityLabel(grid ? "Vista elenco" : "Vista griglia").accessibilityIdentifier("bloom-layout")
            Button { selecting.toggle(); selected = [] } label: {
                Image(systemName: selecting ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
            }.accessibilityLabel(selecting ? "Fine selezione" : "Seleziona").accessibilityIdentifier("bloom-select")
        }
        .foregroundStyle(.primary).buttonStyle(NativePressStyle())
    }
    private var selectionBar: some View {
        HStack(spacing: NativeDesign.Space.small) {
            Text("\(selected.count) selezionate").font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Menu {
                ForEach(store.archive.collections.map { NativeBloomRow($0) }) { row in
                    Button(row.value.text("name")) { perform { try store.updateNotes(selected, category: row.id) } }
                }
                Divider()
                Button("Nuova categoria…", systemImage: "folder.badge.plus") { showingCategories = true }
            } label: { LOActionLabel(title: "Categoria", systemImage: "folder") }
                .buttonStyle(LOGlassButtonStyle()).disabled(selected.isEmpty)
                .accessibilityIdentifier("bloom-assign-category")
            Button { perform { try store.updateNotes(selected, archived: !showTrash) } } label: {
                LOActionLabel(title: showTrash ? "Ripristina" : "Cestino", systemImage: showTrash ? "arrow.uturn.backward" : "trash")
            }.buttonStyle(LOGlassButtonStyle()).disabled(selected.isEmpty)
        }.padding(.horizontal, NativeDesign.Layout.screenInset)
    }
    @ViewBuilder private func destination(_ row: Record, width: CGFloat?) -> some View {
        if selecting {
            Button { let id = row.text("id"); if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } } label: {
                presentation(row, width: width).overlay(alignment: .topTrailing) { Image(systemName: selected.contains(row.text("id")) ? "checkmark.circle.fill" : "circle").padding(NativeDesign.Space.small) }
            }.buttonStyle(.plain)
        } else { NavigationLink { NativeBloomDetail(store: store, id: row.text("id")) } label: { presentation(row, width: width) }.buttonStyle(.plain)
            .accessibilityIdentifier("bloom-note-" + row.text("id"))
            .accessibilityLabel(NativeBloomRow(row).displayTitle) }
    }
    @ViewBuilder private func presentation(_ row: Record, width: CGFloat?) -> some View {
        if grid || rediscovery { card(row, width: width) } else { listRow(row) }
    }
    /// Reading-list row: thumbnail, title on two lines, source · category.
    private func listRow(_ row: Record) -> some View {
        let item = NativeBloomRow(row)
        let categoryNames = store.archive.collections.filter { NativeBloomRow.categories(of: row).contains($0.text("id")) }.map { $0.text("name") }
        let source = NativeBloomAutoFilter.allCases.first { $0 != .all && $0.matches(row) }?.title ?? "Nota"
        return HStack(spacing: NativeDesign.Space.medium) {
            NativeBloomRowThumbnail(fileURL: store.primaryFileURL(row), linkURL: item.previewURL)
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                Text(item.displayTitle).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(([source] + categoryNames).joined(separator: " · ")).font(.footnote).foregroundStyle(NativeDesign.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .padding(.horizontal, NativeDesign.Layout.compactCardInset)
        .padding(.vertical, NativeDesign.Space.small)
        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.bloomRowHeight, alignment: .leading)
        .contentShape(Rectangle())
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
            .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
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
                    Button {
                        editing = row.value.text("id")
                        name = row.value.text("name")
                    } label: {
                        HStack(spacing: NativeDesign.Space.small) {
                            Text(row.value.text("name") + " (\(members.count))")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { _, member in
                                if let url = store.primaryFileURL(member) {
                                    NativeBloomThumbnail(url: url)
                                        .frame(width: NativeDesign.Layout.iconTile, height: NativeDesign.Layout.iconTile)
                                        .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.Space.xs))
                                        .clipShape(RoundedRectangle(cornerRadius: NativeDesign.Space.xs))
                                        .accessibilityHidden(true)
                                }
                            }
                        }.frame(minHeight: max(NativeDesign.Layout.touchTarget, NativeDesign.Layout.iconTile))
                            .contentShape(Rectangle())
                    }.buttonStyle(NativePressStyle()).swipeActions { Button("Elimina", role: .destructive) { deleting = row.value.text("id") } }
                }
            }
            if let error = store.error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Categorie").navigationBarTitleDisplayMode(.inline).toolbar { Button("Fine") { dismiss() } }
            .confirmationDialog("Eliminare la categoria? Le note vengono conservate nella Libreria.", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Elimina categoria", role: .destructive) { guard let deleting else { return }; do { try store.removeCategory(deleting); self.deleting = nil } catch { store.error = error.localizedDescription } }
            }
    }
}
