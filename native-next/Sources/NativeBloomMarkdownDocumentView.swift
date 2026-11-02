import SwiftUI

/// Shared rendered document; reading never changes the original Markdown.
struct NativeBloomMarkdownDocumentView: View {
    let text: String
    var query = ""
    var body: some View {
        let blocks = NativeBloomMarkdownBlock.parse(text)
        LazyVStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .background(!query.isEmpty && block.text.localizedStandardContains(query) ? Color.yellow.opacity(0.15) : Color.clear)
                    .id(index)
            }
        }.foregroundStyle(Color.primary).accessibilityIdentifier("detail-content-text")
    }
    private func rich(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value)
    }
    @ViewBuilder private func blockView(_ block: NativeBloomMarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level):
            Text(rich(block.text)).font(headingFont(level)).bold().padding(.top, NativeDesign.Space.xs).accessibilityAddTraits(.isHeader)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.medium) {
                if block.text.hasPrefix("[ ] ") || block.text.lowercased().hasPrefix("[x] ") {
                    Image(systemName: block.text.lowercased().hasPrefix("[x]") ? "checkmark.square" : "square")
                    Text(rich(String(block.text.dropFirst(4))))
                } else { Text("•"); Text(rich(block.text)) }
            }
        case .quote:
            HStack { Rectangle().fill(Color.accentColor).frame(width: NativeDesign.Layout.calendarMarker); Text(rich(block.text)) }.fixedSize(horizontal: false, vertical: true)
        case .code:
            ScrollView(.horizontal) { Text(block.text).font(.body.monospaced()).padding(NativeDesign.Space.medium) }
                .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius))
        case .paragraph: Text(rich(block.text)).lineSpacing(NativeDesign.Space.xs)
        case .table(let headers, let rows): table(headers: headers, rows: rows)
        }
    }
    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }
    private func table(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .topLeading, horizontalSpacing: NativeDesign.Space.none, verticalSpacing: NativeDesign.Space.none) {
                    GridRow {
                        ForEach(headers.indices, id: \.self) { column in
                            Text(rich(headers[column])).bold().frame(width: column == 0 ? NativeDesign.Layout.bloomMarkdownFirstColumn : NativeDesign.Layout.bloomMarkdownColumn, alignment: .leading).padding(NativeDesign.Space.medium)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }.background(NativeDesign.actionSurface)
                    ForEach(rows.indices, id: \.self) { row in
                        GridRow {
                            ForEach(headers.indices, id: \.self) { column in
                                Text(rich(rows[row][column])).frame(width: column == 0 ? NativeDesign.Layout.bloomMarkdownFirstColumn : NativeDesign.Layout.bloomMarkdownColumn, alignment: .leading).padding(NativeDesign.Space.medium)
                                    .accessibilityLabel("\(headers[column]): \(rows[row][column])")
                            }
                        }.background(row.isMultiple(of: 2) ? NativeDesign.surface : NativeDesign.canvas)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: NativeDesign.controlRadius)).accessibilityIdentifier("markdown-table")
            Label("Scorri la tabella per leggere tutte le colonne", systemImage: "arrow.left.and.right").font(.caption).foregroundStyle(Color.primary.opacity(0.8))
        }
    }
}
