import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Import a provider-owned document as a local copy before dismissing Files.
/// The caller presents its preview from the sheet's onDismiss, never from the
/// picker delegate while UIKit is still dismissing that controller.
struct NativeBloomBackupPicker: UIViewControllerRepresentable {
    let completion: (Result<Data, Error>) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data], asCopy: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--bloom-import-fixture") {
            picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        #endif
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let completion: (Result<Data, Error>) -> Void
        private let onCancel: () -> Void
        private var completed = false
        init(completion: @escaping (Result<Data, Error>) -> Void, onCancel: @escaping () -> Void) {
            self.completion = completion; self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !completed else { return }
            completed = true; onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !completed else { return }
            completed = true
            guard let url = urls.first else {
                completion(.failure(Message(text: "Nessun file selezionato. Riprova l’importazione.")))
                return
            }
            completion(Result { try Self.read(url) })
        }
        private static func read(_ url: URL) throws -> Data {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var result: Result<Data, Error>?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { localURL in
                result = Result {
                    let size = try localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 100 * 1024 * 1024 else { throw Message(text: "Backup superiore a 100 MiB.") }
                    let data = try Data(contentsOf: localURL)
                    guard data.count <= 100 * 1024 * 1024 else { throw Message(text: "Backup superiore a 100 MiB.") }
                    return data
                }
            }
            if let coordinationError { throw coordinationError }
            guard let result else { throw Message(text: "File non disponibile. Scaricalo sul dispositivo e riprova.") }
            return try result.get()
        }
    }
}
