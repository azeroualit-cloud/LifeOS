import SwiftUI

struct NativeBloomImageFraming {
    var top = 0.0
    var bottom = 0.0
    var left = 0.0
    var right = 0.0
    init(_ record: Record = [:]) { top = record.amount("top"); bottom = record.amount("bottom"); left = record.amount("left"); right = record.amount("right") }
    var record: Record { ["top": .number(top), "bottom": .number(bottom), "left": .number(left), "right": .number(right)] }
}
struct NativeBloomFramedImage: View {
    let data: Data
    let framing: Record
    private var image: UIImage? {
        guard let original = UIImage(data: data), let cg = original.cgImage else { return nil }
        let f = NativeBloomImageFraming(framing)
        let width = Double(cg.width), height = Double(cg.height)
        let rect = CGRect(x: width * f.left, y: height * f.top, width: width * (1 - f.left - f.right), height: height * (1 - f.top - f.bottom))
        guard let crop = cg.cropping(to: rect.integral) else { return original }
        return UIImage(cgImage: crop, scale: original.scale, orientation: original.imageOrientation)
    }
    var body: some View {
        if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Anteprima immagine") }
        else { Label("Anteprima non disponibile", systemImage: "photo") }
    }
}
struct NativeBloomFramingEditor: View {
    let data: Data
    @Binding var framing: Record
    var body: some View {
        Form {
            NativeBloomFramedImage(data: data, framing: framing)
            Section("Nascondi i bordi") {
                edge("Alto", key: "top", opposite: "bottom")
                edge("Basso", key: "bottom", opposite: "top")
                edge("Sinistra", key: "left", opposite: "right")
                edge("Destra", key: "right", opposite: "left")
                Button("Mostra originale") { framing = NativeBloomImageFraming().record }
                Text("Il file originale resta intatto. L’inquadratura viene salvata con la nota.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Inquadratura").onAppear { if framing.isEmpty { framing = NativeBloomImageFraming().record } }
    }
    private func edge(_ label: String, key: String, opposite: String) -> some View {
        VStack(alignment: .leading) {
            Text(label)
            Slider(value: Binding(get: { framing.amount(key) }, set: { framing[key] = .number($0) }), in: 0...max(0, min(0.8, 0.9 - framing.amount(opposite))))
                .accessibilityLabel(label)
        }
    }
}
