import SwiftUI

/// Read-only comparison; the import sheet retains the explicit resolution choice.
struct NativeBloomConflictComparison: View {
    let conflict: NativeBloomConflict
    @State private var includeUnchanged = false
    private var keys: [String] {
        Set(conflict.current.keys).union(conflict.incoming.keys).sorted().filter {
            includeUnchanged || conflict.current[$0] != conflict.incoming[$0]
        }
    }
    private func label(_ key: String) -> String {
        ["title": "Titolo", "text": "Testo", "name": "Nome", "kind": "Tipo", "capturedAt": "Data di creazione",
         "modifiedAt": "Ultima modifica", "archived": "Nel Cestino", "trashedAt": "Data nel Cestino",
         "collectionID": "Categoria principale", "tagIDs": "Categorie", "pinnedCategoryIDs": "Categorie fissate",
         "noteLinks": "Link ordinati", "urlString": "Indirizzo", "place": "Luogo", "noteFiles": "Allegati",
         "fileName": "Nome del file", "contentType": "Formato del file", "imageFraming": "Ritaglio",
         "attachmentBytes": "Dimensione allegato (byte)", "attachmentSHA256": "Impronta allegato SHA-256", "id": "Identificativo"] [key] ?? key
    }
    private func value(_ value: JSONValue?, key: String) -> String {
        guard let value, value != .null else { return "Assente" }
        switch value {
        case .string(let text): return text.isEmpty ? "Vuoto" : text
        case .bool(let flag): return flag ? "Sì" : "No"
        case .number(let number) where ["capturedAt", "modifiedAt", "trashedAt", "createdAt"].contains(key):
            return Date(timeIntervalSinceReferenceDate: number).formatted(date: .abbreviated, time: .shortened)
        default:
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? "Non disponibile"
        }
    }
    var body: some View {
        Form {
            Section {
                Text(conflict.title).font(.headline)
                Text("Confronta le differenze prima di scegliere quale versione conservare. Nessun dato viene modificato in questa schermata.").font(.subheadline).foregroundStyle(.secondary)
                Toggle("Mostra anche i campi uguali", isOn: $includeUnchanged)
            }
            if keys.isEmpty { Section { Text("I contenuti coincidono. Il conflitto riguarda le categorie collegate alla nota.") } }
            ForEach(keys, id: \.self) { key in
                Section(label(key)) {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                        Text("LifeOS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(value(conflict.current[key], key: key)).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                        Text("Backup").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(value(conflict.incoming[key], key: key)).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.modifier(NativeListAppearance()).navigationTitle("Confronta versioni").navigationBarTitleDisplayMode(.inline)
    }
}
