import SwiftUI
import UniformTypeIdentifiers

struct NativeBloomMediaPager: View {
    @ObservedObject var store: NativeBloomStore
    let item: Record
    let openFile: (Record) -> Void
    private struct Page: Identifiable {
        let id: String
        let kind: String
        let source: Record
        let text: String
    }
    private var pages: [Page] {
        var result: [Page] = []
        let text = item.text("text", fallback: item.text("notes"))
        if !text.isEmpty { result.append(.init(id: "text", kind: "text", source: [:], text: text)) }
        if !item.text("lifeosFileSHA256").isEmpty { result.append(.init(id: "primary", kind: item.text("kind"), source: item, text: item.text("fileName"))) }
        let links = (item.text("urlString").isEmpty ? [] : [item.text("urlString")]) + (item["noteLinks"]?.array.map(\.string) ?? [])
        for (index, link) in links.enumerated() { result.append(.init(id: "link-\(index)", kind: "link", source: [:], text: link)) }
        for file in item.records("noteFiles") {
            let kind = UTType(file.text("type"))?.conforms(to: .image) == true ? "image" : "file"
            result.append(.init(id: file.text("id"), kind: kind, source: file, text: file.text("name")))
        }
        return result
    }
    var body: some View {
        if pages.count > 1 {
            TabView {
                ForEach(pages) { page in ScrollView { content(page).padding(NativeDesign.Space.medium) }.tag(page.id) }
            }.tabViewStyle(.page(indexDisplayMode: .automatic)).indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: NativeDesign.Layout.bloomPagerHeight)
                .accessibilityLabel("Contenuti della nota, \(pages.count) pagine")
        } else if let page = pages.first { content(page) }
    }
    @ViewBuilder private func content(_ page: Page) -> some View {
        switch page.kind {
        case "text": NativeBloomMarkdownDocumentView(text: page.text)
        case "link":
            if let url = URL(string: page.text), ["http", "https"].contains(url.scheme ?? "") {
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    Label(url.host ?? "Link", systemImage: "link").font(.headline)
                    Link(page.text, destination: url)
                    Text("Il contenuto remoto può richiedere una connessione o l’accesso al sito.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        case "image":
            VStack(alignment: .leading) {
                if let hydrated = try? store.hydrated(page.source), let bytes = Data(base64Encoded: hydrated.text("data")) {
                    NativeBloomFramedImage(data: bytes, framing: page.source.record(page.source.text("kind") == "image" ? "imageFraming" : "framing"))
                        .frame(maxHeight: NativeDesign.Layout.bloomPagerHeight)
                }
                Button("Apri originale") { openFile(page.source) }
            }
        default:
            VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                Label(page.text.isEmpty ? "Allegato" : page.text, systemImage: "doc")
                Button("Apri originale") { openFile(page.source) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
