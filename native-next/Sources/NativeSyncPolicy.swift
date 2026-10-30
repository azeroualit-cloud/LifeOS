import Foundation

struct NativeRefreshScope: OptionSet {
    let rawValue: Int
    static let life = NativeRefreshScope(rawValue: 1)
    static let finance = NativeRefreshScope(rawValue: 2)
    static let all: NativeRefreshScope = [.life, .finance]
}
enum NativeSyncPolicy {
    static func scope(for method: String) -> NativeRefreshScope {
        let life: Set<String> = ["saveActivity", "saveHealthEntry","setRoutineCheck", "saveRoutine", "deleteRoutine", "paintShift", "saveTask", "setTaskStatus", "deleteTask", "deleteCompletedTasks", "reorderTasks", "addCategory", "renameCategory", "deleteCategory", "reorderCategories", "saveEvent", "splitEventSeries", "setEventOccurrence", "deleteEvent"]
        return life.contains(method) ? .life : .finance
    }
    static func isTransient(_ error: Error) -> Bool {
        if let issue = error as? NativeServerUnavailable { return [502, 503, 504].contains(issue.status) }
        guard let error = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(error.code)
    }
    static func canRetry(method: String, error: Error) -> Bool {
        if method.hasPrefix("get"), let issue = error as? NativeServerUnavailable { return [502, 503, 504].contains(issue.status) }
        guard method.hasPrefix("get"), let error = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .cannotConnectToHost].contains(error.code)
    }
}
struct NativeServerUnavailable: LocalizedError {
    let status: Int
    var errorDescription: String? { "Il server è momentaneamente occupato. I dati sul dispositivo sono conservati." }
}

struct NativeRequestRejected: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}
