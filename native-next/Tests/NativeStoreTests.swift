import Foundation
import XCTest
@testable import LifeOSProbe

private final class MockAPI: URLProtocol {
    static let lock = NSLock()
    static var unified = false
    static var writes = 0
    static var failAfterWrite = false
    static var failAll = false
    static var calls: [String] = []
    static var timeoutOnce: String?
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "lifeos-test.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let method = request.url!.lastPathComponent
        Self.calls.append(method)
        if Self.timeoutOnce == method {
            Self.timeoutOnce = nil; Self.lock.unlock()
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return
        }
        var status = 200
        var text = "{}"
        if Self.failAll { status = 401; text = "Sessione scaduta" }
        else if method == "saveActivity" { Self.writes += 1; text = "true" }
        else if method == "setTaskStatus" { text = "true" }
        else if method == "saveTransaction" { Self.writes += 1; text = "true" }
        else if method == "getLifeData" {
            text = Self.unified ? #"{"tasks":[],"categories":[{"key":"action","label":"Attività"}],"routines":[],"events":[],"shifts":[],"upcomingEvents":[],"capabilities":{"unifiedActivities":1}}"# : #"{"tasks":[],"categories":[],"routines":[],"events":[],"shifts":[],"upcomingEvents":[]}"#
        }
        else if method == "getExtraPlan" { text = #"{"allocations":[],"links":[]}"# }
        else if method == "getFinanceData" || method == "getFinanceOverview" {
            if Self.failAfterWrite && Self.writes > 0 { Self.failAfterWrite = false; status = 500; text = "Aggiornamento temporaneamente non disponibile" }
            else { text = #"{"summary":{"budget":1000,"committedCurrent":200,"remainingFree":800},"transactions":[],"extraPlan":{"allocations":[],"links":[]}}"# }
        }
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": status == 200 ? "application/json" : "text/plain", "Set-Cookie": method == "login" && status == 200 ? "liquidita_session=mock-session; Path=/; Max-Age=3600; Secure; HttpOnly; SameSite=Strict" : "", "X-LifeOS-Data-Source": "shared"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor final class NativeStoreTests: XCTestCase {
    private func setup() throws -> (URL, URLSession) {
        MockAPI.lock.lock(); MockAPI.unified = false; MockAPI.writes = 0; MockAPI.failAfterWrite = false; MockAPI.failAll = false; MockAPI.calls = []; MockAPI.timeoutOnce = nil; MockAPI.lock.unlock()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockAPI.self]
        return (directory, URLSession(configuration: config))
    }
    func testDemoEditingExistingActivityKeepsItsIdentifierAndListPosition() async throws {
        let (directory, session) = try setup()
        defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        store.seedVisualActivityAgenda()
        let before = store.tasks.map { $0.integer("id") }
        var p = try XCTUnwrap(store.tasks.first { $0.integer("id") == 101 })
        p["title"] = .string("Da fare libera aggiornata")
        try await store.perform("saveTask", p)
        XCTAssertEqual(store.tasks.first { $0.integer("id") == 101 }?.text("title"), "Da fare libera aggiornata")
        XCTAssertEqual(Set(store.tasks.map { $0.integer("id") }), Set(before))
        XCTAssertEqual(store.tasks.first { $0.integer("id") == 101 }?.amount("sort_order"), p.amount("sort_order"))
        XCTAssertEqual(store.tasks.filter { $0.integer("id") == 101 }.count, 1)
    }
    func testActivitySavePersistsOfflineWithoutWaitingForAnyNetworkRequest() async throws {
        let (directory, session) = try setup()
        defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        MockAPI.unified = true
        await store.sync(scope: .life)
        MockAPI.calls = []; MockAPI.failAll = true
        let p: Record = ["uid": .string("offline-activity"), "source": .string("task"), "sourceId": .int(0), "title": .string("Attività senza attesa"), "notes": .string("Conservata offline"), "list_kind": .string("action"), "frequency": .string("none")]
        try await store.perform("saveActivity", p)
        XCTAssertTrue(MockAPI.calls.isEmpty, "Saving locally must not await a server response")
        XCTAssertEqual(store.tasks.first?.text("title"), "Attività senza attesa")
        XCTAssertEqual(store.state.pending.count, 1)
        let id = try XCTUnwrap(store.state.pending.first?.id)
        let relaunched = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        XCTAssertEqual(relaunched.state.pending.first?.id, id)
        XCTAssertEqual(relaunched.tasks.first?.text("notes"), "Conservata offline")
        await relaunched.sync(scope: .life)
        XCTAssertEqual(relaunched.state.pending.first?.id, id, "A failed retry must retain the original idempotency key")
    }
    func testFailedMonthReadDoesNotTrapNavigationOrMislabelCachedBalance() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        await store.sync(scope: .finance)
        let current = CivilDate.month()
        await store.changeMonth(1, finance: true)
        XCTAssertGreaterThan(store.financeMonth, current)
        MockAPI.failAll = true
        await store.changeMonth(-1, finance: true)
        XCTAssertEqual(store.financeMonth, current)
        XCTAssertTrue(store.finance.isEmpty, "November balances must not appear under October")
        await store.changeMonth(-1, finance: true)
        XCTAssertLessThan(store.financeMonth, current)
        MockAPI.failAll = false
        await store.changeMonth(1, finance: true)
        XCTAssertEqual(store.financeMonth, current)
        XCTAssertFalse(store.finance.isEmpty)
        XCTAssertEqual(store.syncStatus, "Aggiornato")
    }
    func testAnalysisRecoversTheRequestedMonthAfterOverviewFailure() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        await store.sync(scope: .finance)
        await store.loadAnalysis()
        MockAPI.failAll = true
        await store.changeMonth(1, finance: true)
        let requested = store.financeMonth
        XCTAssertFalse(store.analysisIsCurrent)
        MockAPI.failAll = false
        await store.loadAnalysis()
        XCTAssertEqual(store.state.financeMonth, requested)
        XCTAssertTrue(store.analysisIsCurrent)
        XCTAssertFalse(store.finance.isEmpty)
    }
    func testAnalysisInitializesCategoriesBeforeTheHeavyRead() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        await store.sync(scope: .finance)
        MockAPI.calls = []
        await store.loadAnalysis()
        XCTAssertEqual(MockAPI.calls, ["getFinanceCategoryOptions", "getFinanceData"])
        XCTAssertTrue(store.analysisIsCurrent)
    }
    func testDashboardCapsHighlightsAtThreeAndPrioritizesSevenDayEvents() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        store.seedVisualTasks()
        XCTAssertLessThanOrEqual(store.highlights.count, 3)
        XCTAssertEqual(store.highlights.first?.text("highlightKind"), "event")
        XCTAssertTrue(store.highlights.filter { $0.text("highlightKind") == "task" }.allSatisfy { $0.text("status") == "todo" })
    }
    private var payload: Record { ["requestId": .string("regression-12345678"), "type": .string("Spesa"), "name": .string("Spesa da conservare"), "amount": .number(2), "account": .string("Trade Republic"), "category": .string("Altro"), "date": .string(CivilDate.day())] }
    func testNativeSignInReceivesSecureCookieWithoutLoadingWebPage() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        try await store.signIn(password: "not-a-real-password-for-unit-tests")
        XCTAssertEqual(MockAPI.calls, ["login"])
        XCTAssertTrue(store.sharedDatabase)
        let backup = String(decoding: try store.backupData(), as: UTF8.self)
        XCTAssertFalse(backup.contains("not-a-real-password"))
        XCTAssertFalse(backup.contains("mock-session"))
    }
    func testRefreshUsesOneLightFinanceReadAndEmbeddedPlan() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        await store.sync()
        XCTAssertNil(store.error)
        XCTAssertEqual(MockAPI.calls.filter { $0 == "getLifeData" }.count, 1)
        XCTAssertEqual(MockAPI.calls.filter { $0 == "getFinanceOverview" }.count, 1)
        XCTAssertFalse(MockAPI.calls.contains("getFinanceData"))
        XCTAssertFalse(MockAPI.calls.contains("getExtraPlan"))
    }
    func testLifeMutationDoesNotFetchFinanceOrAnalytics() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        await store.sync()
        let financeDate = store.state.financeRefreshedAt
        MockAPI.calls = []
        try await store.perform("setTaskStatus", ["id": .int(1), "status": .string("done")])
        await store.sync(scope: .life)
        XCTAssertEqual(MockAPI.calls, ["setTaskStatus", "getLifeData"])
        XCTAssertEqual(store.state.financeRefreshedAt, financeDate)
    }
    func testTransientReadTimeoutRetriesOnceButMutationIsNeverRetriedAutomatically() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        MockAPI.timeoutOnce = "getLifeData"
        _ = try await store.read("getLifeData")
        XCTAssertEqual(MockAPI.calls.filter { $0 == "getLifeData" }.count, 2)
        MockAPI.timeoutOnce = "saveTransaction"
        do { _ = try await store.read("saveTransaction", args: [.object(payload)]); XCTFail("Expected timeout") }
        catch { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
        XCTAssertEqual(MockAPI.calls.filter { $0 == "saveTransaction" }.count, 1)
    }
    func testAutomaticAuthenticationFailureKeepsCacheAndQueueWithoutModalError() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        MockAPI.failAll = true
        try await store.perform("saveTransaction", payload)
        await store.sync(automatic: true)
        XCTAssertNil(store.error)
        XCTAssertNotNil(store.notice)
        XCTAssertEqual(store.state.pending.first?.payload, payload)
        XCTAssertFalse(store.state.pending.first!.accepted)
    }
    func testFirstConnectionPreservesLocalTwoEuroWriteAcrossRelaunchThenSendsOnce() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let initial = NativeArchive(pending: [PendingWrite(id: "regression-12345678", method: "saveTransaction", payload: payload)], demo: false)
        try JSONEncoder().encode(initial).write(to: directory.appendingPathComponent("lifeos-native-v2.json"))
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        XCTAssertEqual(store.state.pending.first?.payload, payload)
        XCTAssertEqual(MockAPI.writes, 0)
        let relaunched = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        XCTAssertEqual(relaunched.state.endpoint, "https://lifeos-test.invalid")
        XCTAssertEqual(relaunched.state.pending.first?.id, "regression-12345678")
        XCTAssertEqual(relaunched.state.pending.first?.payload.amount("amount"), 2)
        await relaunched.sync()
        XCTAssertNil(relaunched.error)
        XCTAssertTrue(relaunched.state.pending.isEmpty)
        await relaunched.sync()
        XCTAssertEqual(MockAPI.writes, 1)
    }
    func testConfirmedWriteWithoutKnownServerCannotBeAssignedElsewhere() throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let initial = NativeArchive(pending: [PendingWrite(id: "regression-12345678", method: "saveTransaction", payload: payload, accepted: true)], demo: false)
        let file = directory.appendingPathComponent("lifeos-native-v2.json")
        try JSONEncoder().encode(initial).write(to: file)
        let original = try Data(contentsOf: file)
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        XCTAssertThrowsError(try store.configure("https://lifeos-test.invalid"))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testConfiguringServerResetsDisplayedMonthsToTheNewArchive() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        await store.changeMonth(-1, finance: true)
        await store.changeMonth(1, finance: false)
        try store.configure("https://lifeos-test.invalid")
        XCTAssertEqual(store.financeMonth, store.state.financeMonth)
        XCTAssertEqual(store.calendarMonth, store.state.calendarMonth)
        XCTAssertEqual(store.financeMonth, CivilDate.month())
    }
    func testConfirmedWriteSurvivesFailedRefreshAndRelaunchWithoutResending() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        MockAPI.failAfterWrite = true
        try await store.perform("saveTransaction", payload)
        await store.sync(automatic: true)
        XCTAssertEqual(store.state.pending.count, 1)
        XCTAssertEqual(store.state.pending.first?.accepted, true)
        XCTAssertNotNil(store.notice)
        let relaunched = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        await relaunched.sync()
        XCTAssertTrue(relaunched.state.pending.isEmpty)
        XCTAssertNil(relaunched.error)
        XCTAssertEqual(MockAPI.writes, 1)
    }
    func testDemoSwitchAndRestoreKeepUnsentWriteAndEndpoint() async throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        try store.configure("https://lifeos-test.invalid")
        MockAPI.failAll = true
        try await store.perform("saveTransaction", payload)
        await store.sync(automatic: true)
        XCTAssertEqual(store.state.pending.count, 1)
        XCTAssertThrowsError(try store.configure("https://different-test.invalid"))
        try store.configure("https://lifeos-test.invalid/")
        try store.useDemo()
        XCTAssertTrue(store.isDemo)
        XCTAssertTrue(store.state.pending.isEmpty)
        let backup = try JSONDecoder().decode(JSONValue.self, from: store.backupData()).object
        XCTAssertEqual(backup.record("previous").records("pending").count, 1)
        try store.restoreConnection()
        XCTAssertFalse(store.isDemo)
        XCTAssertEqual(store.state.pending.first?.id, "regression-12345678")
        XCTAssertEqual(store.state.endpoint, "https://lifeos-test.invalid")
    }
    func testSnapshotImportPreservesExistingUnsentWrite() throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let initial = NativeArchive(pending: [PendingWrite(id: "regression-12345678", method: "saveTransaction", payload: payload)], demo: false)
        try JSONEncoder().encode(initial).write(to: directory.appendingPathComponent("lifeos-native-v2.json"))
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        let data = Data(#"{"summary":{"budget":1000,"committedCurrent":200,"remainingFree":800},"transactions":[]}"#.utf8)
        try store.importFinance(data)
        XCTAssertEqual(store.state.pending.first?.id, "regression-12345678")
        XCTAssertEqual(store.summary.amount("budget"), 1000)
    }
    func testMigrationKeepsLegacyQueueUUIDAndOriginalSQLite() throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let expense = try Input.expense(amount: "2", name: "Spesa del prototipo", category: "Altro", date: Date(), months: 1, treatment: "auto")
        let legacy = try Storage(folder: directory)
        try legacy.save(Archive(queue: [expense]))
        let store = NativeStore(directory: directory, session: session)
        XCTAssertFalse(store.isDemo)
        XCTAssertEqual(store.state.pending.first?.id, expense.requestId)
        XCTAssertEqual(store.state.pending.first?.payload.amount("amount"), 2)
        XCTAssertEqual(try legacy.load().queue.first?.requestId, expense.requestId)
    }
    func testCorruptArchiveIsNeverReplacedByDemoOrServerConfiguration() throws {
        let (directory, session) = try setup(); defer { try? FileManager.default.removeItem(at: directory); session.invalidateAndCancel() }
        let file = directory.appendingPathComponent("lifeos-native-v2.json"), original = Data("JSON incompleto".utf8)
        try original.write(to: file)
        let store = NativeStore(directory: directory, session: session, migrateLegacy: false, automaticallySyncsWrites: false)
        XCTAssertNotNil(store.error)
        XCTAssertThrowsError(try store.useDemo())
        XCTAssertThrowsError(try store.configure("https://lifeos-test.invalid"))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}
