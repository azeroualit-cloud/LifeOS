import SwiftUI
import LinkPresentation
import CryptoKit

struct NativeBloomLinkSnapshot: Codable {
    var title: String
    var image: Data?
    var fetchedAt = Date()
}

/// A disposable cache, separate from the archive: fetching never edits a note.
@MainActor final class NativeBloomLinkPreviews {
    static let shared = NativeBloomLinkPreviews()
    private var pending: [URL: Task<NativeBloomLinkSnapshot?, Never>] = [:]
    private var failures: [URL: Date] = [:]
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("BloomLinkPreviews", isDirectory: true)
    func load(_ url: URL) async -> NativeBloomLinkSnapshot? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--bloom-grid-fixture") {
            guard url.path != "/unavailable" else { return nil }
            return NativeBloomLinkSnapshot(title: "Anteprima del link di esempio", image: NativeBloomVisualFixture.image(width: 600, height: 320))
        }
        #endif
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(key + ".json")
        let cached = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(NativeBloomLinkSnapshot.self, from: $0) }
        if let cached, Date().timeIntervalSince(cached.fetchedAt) < 7 * 86400 { return cached }
        if let failed = failures[url], Date().timeIntervalSince(failed) < 60 { return cached }
        if let task = pending[url] { return await task.value }
        let task = Task { @MainActor () -> NativeBloomLinkSnapshot? in
            let provider = LPMetadataProvider()
            provider.timeout = 8
            let metadata: LPLinkMetadata? = await withCheckedContinuation { continuation in
                provider.startFetchingMetadata(for: url) { metadata, _ in continuation.resume(returning: metadata) }
            }
            guard let metadata else { return nil }
            var bytes: Data?
            if let imageProvider = metadata.imageProvider, imageProvider.canLoadObject(ofClass: UIImage.self) {
                let image: UIImage? = await withCheckedContinuation { continuation in
                    imageProvider.loadObject(ofClass: UIImage.self) { image, _ in continuation.resume(returning: image as? UIImage) }
                }
                if let image, image.size.width > 0, image.size.height > 0 {
                    let scale = min(1, 512 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    bytes = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.8)
                }
            }
            return NativeBloomLinkSnapshot(title: metadata.title ?? "", image: bytes)
        }
        pending[url] = task
        let snapshot = await task.value
        pending[url] = nil
        guard let snapshot else {
            if failures.count > 200 { failures.removeAll() }
            failures[url] = Date(); return cached
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            if files.count > 200 {
                let sorted = files.sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
                for old in sorted.prefix(files.count - 200) { try? FileManager.default.removeItem(at: old) }
            }
        } catch { /* Cache failure must never prevent opening the original note. */ }
        return snapshot
    }
}

struct NativeBloomLinkPreview: View {
    let url: URL
    let width: CGFloat
    var showTitle = true
    @State private var snapshot: NativeBloomLinkSnapshot?
    @State private var finished = false
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            if let bytes = snapshot?.image, let image = UIImage(data: bytes) {
                Image(uiImage: image).resizable().scaledToFit().frame(width: width).clipped()
                    .accessibilityLabel("Anteprima link").accessibilityIdentifier("bloom-link-image")
            } else {
                ZStack {
                    NativeDesign.inset
                    Image(systemName: "link").font(.title2).foregroundStyle(.secondary)
                }.frame(width: width, height: NativeDesign.Layout.bloomThumbnailHeight)
                    .accessibilityLabel(finished ? "Anteprima non disponibile" : "Caricamento anteprima")
            }
            if showTitle, let title = snapshot?.title, !title.isEmpty {
                Text(title).font(.subheadline).lineLimit(3).multilineTextAlignment(.leading)
            }
            Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.frame(width: width, alignment: .leading)
            .task(id: url) {
                snapshot = nil; finished = false
                let value = await NativeBloomLinkPreviews.shared.load(url)
                guard !Task.isCancelled else { return }
                snapshot = value; finished = true
            }
    }
}
