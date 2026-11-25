import SwiftUI

#if DEBUG
/// Debug-only gallery (launch argument --icon-gallery) to choose the «Incontri» icon with real SF Symbols.
struct NativeIconGallery95: View {
    static let symbols = [
        "moon", "moon.stars", "moon.haze", "cloud.moon", "sparkle", "sparkles",
        "star", "sun.haze", "sun.horizon", "sunset", "sun.min", "rays",
        "flame", "drop", "leaf", "camera.macro", "wind", "rainbow",
        "seal", "circle.hexagongrid", "circle.circle", "infinity", "link", "hourglass",
        "wand.and.stars", "music.note", "wineglass", "cup.and.saucer", "key", "bubbles.and.sparkles"
    ]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: NativeDesign.Space.small), count: 3)
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: NativeDesign.Space.medium) {
                ForEach(Array(Self.symbols.enumerated()), id: \.offset) { index, name in
                    VStack(spacing: NativeDesign.Space.xs) {
                        Image(systemName: name).font(.title).foregroundStyle(NativeDesign.accent)
                        Label("Incontri", systemImage: name).font(.footnote).foregroundStyle(NativeDesign.secondary)
                        Text("\(index + 1) · \(name)").font(.caption2).foregroundStyle(NativeDesign.secondary).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NativeDesign.Space.small)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: NativeDesign.Space.small))
                    .accessibilityIdentifier("icon-\(index + 1)")
                }
            }
            .padding(NativeDesign.Space.medium)
        }
    }
}
#endif
