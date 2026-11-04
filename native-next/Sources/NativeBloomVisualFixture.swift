import SwiftUI

enum NativeBloomVisualFixture {
    @MainActor static func store() -> NativeBloomStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--bloom-grid-fixture") {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("BloomGridFixture")
            let store = NativeBloomStore(directory: root)
            if store.archive.items.isEmpty {
                do {
                    try seed(store)
                } catch { store.error = error.localizedDescription }
            }
            return store
        }
        #endif
        return .shared
    }
    #if DEBUG
    @MainActor static func seed(_ store: NativeBloomStore) throws {
        for index in 0..<122 {
            let kind = index % 4 == 0 ? "image" : (index % 4 == 1 ? "link" : "text")
            var row: Record = ["id": .string(String(format: "BA000000-0000-4000-8000-%012d", index)), "kind": .string(kind), "urlString": .string(""), "title": .string(index == 0 ? "Immagine verticale" : "Nota \(index): titolo lungo per verificare le colonne della libreria"), "capturedAt": .number(Double(10000 - index)), "archived": .bool(false), "noteVersion": .int(1)]
            if kind == "image" {
                let portrait = index % 8 == 0
                row["data"] = .string(image(width: portrait ? 280 : 1000, height: portrait ? 500 : 240).base64EncodedString())
                row["fileName"] = .string("fixture.jpg"); row["contentType"] = .string("public.jpeg")
            } else if kind == "link" {
                row["urlString"] = .string("https://example.com/" + (index == 5 ? "unavailable" : "preview"))
            } else { row["text"] = .string(index % 2 == 0 ? "Testo breve" : String(repeating: "Una nota con contenuto piu lungo. ", count: 8)) }
            try store.save(row)
        }
    }
    @MainActor static func image(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.systemIndigo.setFill(); context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }.jpegData(compressionQuality: 0.8)!
    }
    #endif
}
