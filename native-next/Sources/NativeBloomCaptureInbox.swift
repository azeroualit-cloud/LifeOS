import Foundation
import Combine

@MainActor final class NativeBloomCaptureInbox: ObservableObject {
    static let shared = NativeBloomCaptureInbox()
    struct Request: Codable, Identifiable { let id: UUID; let row: Record; let date: Date }
    @Published private(set) var requests: [Request] = []
    @Published private(set) var error: String?
    private var available = false
    private let file: URL
    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LifeOSBloom", isDirectory: true)
        file = root.appendingPathComponent("capture-inbox.json")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { requests = try JSONDecoder().decode([Request].self, from: Data(contentsOf: file)) }
            available = true
        } catch { self.error = "Catture in sospeso non leggibili: " + error.localizedDescription }
    }
    private func persist(_ next: [Request]) throws {
        guard available else { throw Message(text: error ?? "Archivio catture non disponibile.") }
        try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtection]); requests = next
    }
    func capture(_ row: Record, in store: NativeBloomStore) throws {
        guard let id = UUID(uuidString: row.text("id")), requests.count < 200 else { throw Message(text: "Completa prima le catture in sospeso.") }
        let request = Request(id: id, row: row, date: Date())
        try persist(requests + [request])
        try retry(request, in: store)
    }
    func retry(_ request: Request, in store: NativeBloomStore) throws {
        guard requests.contains(where: { $0.id == request.id }) else { return }
        // A crash after the note commit must never overwrite a later user edit.
        if !store.archive.items.contains(where: { $0.text("id") == request.row.text("id") }) { try store.save(request.row) }
        try persist(requests.filter { $0.id != request.id }); error = nil
    }
}
