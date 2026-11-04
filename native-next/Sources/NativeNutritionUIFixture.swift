import Foundation

@MainActor enum NativeNutritionUIFixture {
    static var current: NativeNutritionStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--nutrition-ui-fixture") { return fixture }
        #endif
        return .shared
    }
    #if DEBUG
    private static let fixture = NativeNutritionStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), writer: Writer())
    private final class Writer: NativeNutritionWriting {
        private var attempted = false
        func authorize(includeFibre: Bool) async throws {}
        func write(_ entry: NativeNutritionEntry) async throws {
            if !attempted && ProcessInfo.processInfo.arguments.contains("--nutrition-write-failure") {
                attempted = true; throw Message(text: "Scrittura interrotta. Riprova senza reinserire i valori.")
            }
        }
        func delete(_ entry: NativeNutritionEntry) async throws {}
    }
    #endif
}
