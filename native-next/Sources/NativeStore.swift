import Foundation
import SwiftUI

@MainActor final class NativeStore: ObservableObject {
    @Published private(set) var state = NativeArchive()
    @Published private(set) var busy = false
    @Published private(set) var syncing = false
    private var syncTask: Task<Void, Never>?
    private let automaticallySyncsWrites: Bool
    @Published var error: String?
    @Published var notice: String?
    @Published var financeMonth = CivilDate.month()
    @Published var calendarMonth = CivilDate.month()
    @Published var weather = ""
    @Published private(set) var weatherDetails: NativeWeather?
    @Published private(set) var weatherDate: Date?
    @Published private(set) var syncStatus = ""
    @Published private(set) var plansBusy = false
    @Published private(set) var plansError: String?
    @Published private(set) var analysisBusy = false
    @Published private(set) var financeGeneration = 0
    @Published private(set) var sharedDatabase = false
    private var weatherBusy = false
    private var analysisGeneration = -1
    private var lastAutomaticSync = Date.distantPast
    private let persistsSession: Bool
    private let file: URL
    private let session: URLSession
    private var connectionFile: URL { file.deletingLastPathComponent().appendingPathComponent("lifeos-connection-backup.json") }
    var hasSavedConnection: Bool { FileManager.default.fileExists(atPath: connectionFile.path) }
    private var revision = 0
    private var archiveWritable = true
    var server: URL? { state.endpoint.flatMap(URL.init(string:)) }
    var isDemo: Bool { state.demo }
    var life: Record { state.life }
    var finance: Record { isDemo || financeMonth == state.financeMonth ? state.finance : [:] }
    var summary: Record { finance.record("summary") }
    private var transferablePending: [PendingWrite] { state.pending.filter { $0.method != "saveHealthEntry" } }
    var financialPending: [PendingWrite] { state.pending.filter { ["saveTransaction", "saveExtra"].contains($0.method) } }
    var tasks: [Record] { life.records("tasks") }
    var categories: [Record] { life.records("categories").sorted { $0.amount("position") < $1.amount("position") } }
    var routines: [Record] { life.records("routines").map { record in
        var r = record; if life.text("today") != CivilDate.day() { r["checked"] = .bool(false) }; return r
    } }
    var todayRoutines: [Record] { routines.filter { NativeRoutineSchedule.due($0) } }
    var transactions: [Record] { finance.records("transactions").filter { !isDemo || $0.text("date").hasPrefix(financeMonth) }.sorted { $0.text("date") > $1.text("date") } }
    var allocations: [Record] { state.plan.records("allocations") }
    var dashboardEvents: [Record] {
        let today = CivilDate.day()
        return isDemo ? expandedEvents(low: today, high: CivilDate.adding(7, to: today), source: life.records("events")) : life.records("upcomingEvents")
    }
    var events: [Record] {
        guard isDemo else { return life.records("events") }
        let low = CivilDate.adding(-1, to: calendarMonth + "-01", component: .month)
        let high = CivilDate.adding(2, to: calendarMonth + "-01", component: .month)
        return expandedEvents(low: low, high: high, source: life.records("events"))
    }
    var highlights: [Record] {
        let upcoming: [Record]
        if isDemo {
            let now = Date(), hour = CivilDate.calendar.component(.hour, from: now), minute = CivilDate.calendar.component(.minute, from: now)
            let clock = String(format: "%02d:%02d", hour, minute)
            upcoming = expandedEvents(low: CivilDate.day(), high: CivilDate.adding(7, to: CivilDate.day()), source: life.records("events"))
                .filter { $0.text("occurrence_status", fallback: "open") == "open" && ($0.text("day") > CivilDate.day() || $0.text("start_time").isEmpty || $0.text("start_time") >= clock) }
        } else { upcoming = life.records("upcomingEvents") }
        let first = CivilDate.day(), last = CivilDate.adding(6, to: CivilDate.day())
        let priority = upcoming.filter { $0.text("day") >= first && $0.text("day") <= last && $0.text("occurrence_status", fallback: "open") == "open" }
            .sorted { ($0.text("day"), $0.text("start_time")) < ($1.text("day"), $1.text("start_time")) }
        let events = priority.prefix(3).map { row -> Record in var r = row; r["highlightKind"] = .string("event"); return r }
        let todo = tasks.filter { $0.text("list_kind") == "action" && $0.text("status") == "todo" }.sorted {
            let a = $0.text("due_date", fallback: "9999"), b = $1.text("due_date", fallback: "9999")
            return a == b ? $0.amount("sort_order") < $1.amount("sort_order") : a < b
        }.prefix(max(0, 3 - events.count)).map { row -> Record in var r = row; r["highlightKind"] = .string("task"); return r }
        return events + todo
    }
    init(directory: URL? = nil, session injectedSession: URLSession? = nil, migrateLegacy: Bool = true, automaticallySyncsWrites: Bool = true) {
        self.automaticallySyncsWrites = automaticallySyncsWrites
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 40; config.timeoutIntervalForResource = 90
        persistsSession = injectedSession == nil
        session = injectedSession ?? URLSession(configuration: config)
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appendingPathComponent("lifeos-native-v2.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                state = try JSONDecoder().decode(NativeArchive.self, from: Data(contentsOf: file))
            } else {
                var initial = DemoData.make()
                let legacy = migrateLegacy ? try Storage(folder: folder).load() : Archive()
                if !legacy.queue.isEmpty || !legacy.confirmed.isEmpty || legacy.finance != nil {
                    initial.demo = false
                    initial.imported = true
                    initial.life = DemoData.emptyLife()
                    initial.plan = [:]
                    initial.endpoint = UserDefaults.standard.string(forKey: "test-server")
                    if let finance = legacy.finance {
                        initial.finance = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(finance)).object
                    } else { initial.finance = [:] }
                    initial.pending = try legacy.queue.map { e in
                        PendingWrite(id: e.requestId, method: "saveTransaction", payload: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(e)).object)
                    } + legacy.confirmed.map { e in
                        PendingWrite(id: e.requestId, method: "saveTransaction", payload: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(e)).object, accepted: true)
                    }
                }
                try save(initial)
            }
            financeMonth = state.financeMonth; calendarMonth = state.calendarMonth
            rollover()
            if persistsSession, let server { acceptCookies(SessionVault.load(origin: server.absoluteString)) }
        } catch { archiveWritable = false; self.error = "Archivio non disponibile: \(error.localizedDescription). I dati precedenti non sono stati cancellati." }
    }
    #if DEBUG
    func seedVisualOffDayHabit() {
        guard isDemo else { return }
        var demo = state
        let schedule: Record = ["mode": .string("daily"), "startDate": .string(CivilDate.adding(1, to: CivilDate.day()))]
        var rows = demo.life.records("routines")
        rows.append(["id": .int(999), "title": .string("Abitudine di domani"), "schedule": .object(schedule)])
        demo.life["routines"] = .array(rows.map(JSONValue.object))
        try? save(demo)
    }
    func seedVisualHome(empty: Bool) {
        guard isDemo else { return }
        var demo = state
        if empty {
            for key in ["events", "tasks", "routines", "shifts"] { demo.life[key] = .array([]) }
            demo.finance["summary"] = .object([:])
        } else {
            let today = CivilDate.day()
            demo.life["events"] = .array((1...12).map { i in .object(["id": .int(i), "day": .string(CivilDate.adding(i % 5, to: today)), "title": .string("Appuntamento \(i)"), "frequency": .string("none")]) })
            demo.life["routines"] = .array((1...8).map { i in .object(["id": .int(i), "title": .string(i == 1 ? "Abitudine con un nome molto lungo da leggere senza sovrapposizioni" : "Abitudine \(i)"), "checked": .bool(i % 2 == 0)]) })
        }
        try? save(demo)
    }
    func seedVisualMoney() {
        var demo = state
        var summary = demo.finance.record("summary")
        summary["budget"] = .number(12345.67); summary["committedCurrent"] = .number(345.67); summary["remainingFree"] = .number(12000)
        summary["monthlyRemaining"] = .number(-1234.56)
        demo.finance["summary"] = .object(summary)
        let names = ["Casa", "Alimentari", "Ristorazione", "Benzina", "Shopping", "Abbonamenti", "Salute", "Svago"]
        demo.finance["categories"] = .array(names.enumerated().map { index, name in .object(["name": .string(name), "amount": .number(Double(800 - index * 90))]) })
        try? save(demo)
    }
    func seedVisualTasks() {
            var demo = state
            let sample = demo.life.records("tasks").first ?? [:]
            demo.life["tasks"] = .array((1...60).map { i in
                var row = sample; row["id"] = .int(i); row["title"] = .string("Attività lunga di verifica \(i): pianificare e organizzare gli impegni della settimana"); row["notes"] = .string("Nota su due righe per controllare l’allineamento e lo scorrimento della lista."); row["status"] = .string(i % 3 == 0 ? "waiting" : "todo"); row["sort_order"] = .int(i)
                return .object(row)
            })
            try? save(demo)
    }
    #endif
    private func save(_ next: NativeArchive) throws {
        guard archiveWritable else { throw Message(text: "L’archivio esistente non è leggibile. Conserva i file prima di tentare un recupero.") }
        let data = try JSONEncoder().encode(next)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        state = next
    }
    func rollover() {
        // A finance-only archive has no daily habit state to migrate.
        guard state.demo || !routines.isEmpty else { return }
        let today = CivilDate.day()
        let previousDay = state.demo ? state.routineDay : state.life.text("today", fallback: state.routineDay)
        guard previousDay != today else { return }
        var next = state
        next.routineDay = today; next.life["today"] = .string(today)
        next.life["routines"] = .array(routines.map { var r = $0; r["checked"] = .int(0); return .object(r) })
        do {
            for write in next.pending where write.method == "setRoutineCheck" {
                try LocalLifeMutation.apply(write.method, write.payload, to: &next.life)
            }
            try save(next)
        } catch { self.error = error.localizedDescription }
    }
    func configure(_ raw: String) throws {
        guard !busy, !syncing else { throw Message(text: "Attendi la fine dell’operazione.") }
        guard let u = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)), u.scheme == "https", let host = u.host,
              u.user == nil, u.password == nil, u.query == nil, u.fragment == nil, u.path.isEmpty || u.path == "/" else {
            throw Message(text: "Inserisci l’indirizzo HTTPS del server Life OS.")
        }
        let clean = "https://" + host + (u.port.map { ":\($0)" } ?? "")
        let firstConnection = state.endpoint == nil && !state.pending.contains(where: { $0.accepted })
        guard state.pending.isEmpty || clean == state.endpoint || firstConnection else {
            throw Message(text: "Ci sono movimenti da conservare: non possono essere inviati automaticamente a un altro server.")
        }
        if state.endpoint == clean { return }
        revision += 1
        var next = NativeArchive(); next.demo = false; next.endpoint = clean
        // A local write created before the first connection has no server to leave.
        // Keep its UUID/payload and persist the destination before any network request.
        next.pending = state.pending
        try save(next)
        weatherDetails = nil; weatherDate = nil; weather = ""
        sharedDatabase = false; analysisGeneration = -1; financeGeneration += 1
        financeMonth = state.financeMonth; calendarMonth = state.calendarMonth
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
    }
    func useDemo() throws {
        guard archiveWritable else { throw Message(text: "L’archivio precedente non è leggibile e non verrà sovrascritto.") }
        guard !busy, !syncing else { throw Message(text: "Attendi la fine dell’operazione.") }
        guard !state.demo else { notice = "La demo è già aperta. Le modifiche locali sono conservate."; return }
        if !state.demo {
            try JSONEncoder().encode(state).write(to: connectionFile, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        revision += 1
        try save(DemoData.make())
        weatherDetails = nil; weatherDate = nil; weather = ""
        sharedDatabase = false; analysisGeneration = -1; financeGeneration += 1
        financeMonth = state.financeMonth; calendarMonth = state.calendarMonth
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        notice = "Demo con dati simulati. Nessuna connessione al database."
    }
    func restoreConnection() throws {
        guard !busy, !syncing, state.demo, hasSavedConnection else { throw Message(text: "L’archivio precedente si ripristina dalla demo.") }
        let previous = try JSONDecoder().decode(NativeArchive.self, from: Data(contentsOf: connectionFile))
        revision += 1
        try save(previous)
        weatherDetails = nil; weatherDate = nil; weather = ""
        sharedDatabase = false; analysisGeneration = -1; financeGeneration += 1
        financeMonth = state.financeMonth; calendarMonth = state.calendarMonth
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
    }
    func importFinance(_ data: Data) throws {
        guard server == nil, !busy, !syncing else { throw Message(text: "L’importazione locale è disponibile senza un server configurato.") }
        let snapshot = try NativeValidation.snapshot(data)
        var next = state; next.finance = snapshot; next.demo = false; next.imported = true
        let key = snapshot.text("key")
        let months = Set(snapshot.records("transactions").map { String($0.text("date").prefix(7)) })
        if key.range(of: #"^20\d\d-(0[1-9]|1[0-2])$"#, options: .regularExpression) != nil { next.financeMonth = key }
        else if months.count == 1, let month = months.first { next.financeMonth = month }
        next.life = DemoData.emptyLife(); next.plan = [:]; next.refreshedAt = Date(); next.financeRefreshedAt = Date()
        try save(next); financeMonth = next.financeMonth; notice = "Snapshot importato. I movimenti locali sono conservati."
    }
    func backupData() throws -> Data {
        guard archiveWritable else { throw Message(text: "L’archivio non è leggibile. Conserva il file originale per il recupero.") }
        let current = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(state))
        var result: Record = ["format": .string("LifeOS-native-backup-v2"), "current": current]
        if hasSavedConnection { result["previous"] = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: connectionFile)) }
        return try JSONEncoder().encode(JSONValue.object(result))
    }
    func acceptCookies(_ cookies: [HTTPCookie]) {
        guard let server else { return }
        let matching = cookies.filter { c in
            let domain = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
            return domain == server.host || (c.domain.hasPrefix(".") && server.host!.hasSuffix("." + domain))
        }
        session.configuration.httpCookieStorage?.setCookies(matching, for: server, mainDocumentURL: server)
        if persistsSession, !matching.isEmpty, !SessionVault.save(matching, origin: server.absoluteString) {
            notice = "Accesso riuscito. La sessione non è stata conservata nel Portachiavi: potresti dover accedere di nuovo alla prossima apertura."
        }
    }
    func signIn(password: String) async throws {
        guard let server else { throw Message(text: "Collega prima il tuo server Life OS.") }
        guard !busy, !syncing else { throw Message(text: "Attendi la fine dell’aggiornamento e riprova.") }
        busy = true; defer { busy = false }
        var request = URLRequest(url: server.appendingPathComponent("auth/login"))
        request.httpMethod = "POST"; request.timeoutInterval = 40
        request.setValue(server.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "X-LifeOS-Plans-Version")
        request.httpBody = try JSONEncoder().encode(["user": "nas", "password": password])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.url?.host == server.host,
              http.url?.scheme == server.scheme, http.url?.port == server.port else { throw Message(text: "Risposta di accesso non valida.") }
        guard http.statusCode == 200 else { throw Message(text: http.statusCode == 401 ? "Password non valida." : "Accesso non riuscito. Riprova tra poco.") }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { $0[String(describing: $1.key)] = String(describing: $1.value) }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: server)
        guard cookies.contains(where: { $0.name == "liquidita_session" && $0.isSecure }) else { throw Message(text: "Il server non ha confermato la sessione.") }
        if http.value(forHTTPHeaderField: "X-LifeOS-Data-Source") == "shared" { sharedDatabase = true }
        acceptCookies(cookies)
    }
    func read(_ method: String, args: [JSONValue] = []) async throws -> JSONValue {
        for attempt in 0...1 {
            do { return try await requestOnce(method, args: args) }
            catch {
                guard attempt == 0, NativeSyncPolicy.canRetry(method: method, error: error) else { throw error }
                try await Task.sleep(nanoseconds: 400_000_000)
            }
        }
        throw URLError(.unknown)
    }
    private func requestOnce(_ method: String, args: [JSONValue]) async throws -> JSONValue {
        guard let server else { throw Message(text: "Collega prima Life OS nelle Impostazioni.") }
        var request = URLRequest(url: server.appendingPathComponent("api/" + method))
        request.httpMethod = "POST"; request.setValue(server.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "X-LifeOS-Plans-Version")
        request.httpBody = try JSONEncoder().encode(args)
        request.timeoutInterval = 40
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.url?.host == server.host, http.url?.scheme == server.scheme,
              http.url?.port == server.port else {
            throw Message(text: "Accedi a Life OS nelle Impostazioni.")
        }
        if http.value(forHTTPHeaderField: "X-LifeOS-Data-Source") == "shared" { sharedDatabase = true }
        guard (200..<300).contains(http.statusCode) else {
            if [429, 500, 502, 503, 504].contains(http.statusCode) { throw NativeServerUnavailable(status: http.statusCode) }
            if http.mimeType == "application/json", let value = try? JSONDecoder().decode(JSONValue.self, from: data),
               case .string(let message)? = value.object["error"], !message.isEmpty { throw NativeRequestRejected(status: http.statusCode, message: NativePlanRules.serverError(message, status: http.statusCode, method: method)) }
            let text = String(data: data, encoding: .utf8) ?? ""
            if http.mimeType == "text/html" { throw Message(text: "Accedi a Life OS nelle Impostazioni.") }
            throw NativeRequestRejected(status: http.statusCode, message: text.isEmpty ? "Operazione rifiutata (\(http.statusCode))." : NativePlanRules.serverError(text, status: http.statusCode, method: method))
        }
        guard http.mimeType == "application/json" else { throw Message(text: "Il server non ha restituito JSON. Verifica l’accesso a Life OS.") }
        let result = try JSONDecoder().decode(JSONValue.self, from: data)
        return result
    }
    private func fetchPart(_ method: String, args: [JSONValue], needed: Bool) async -> Result<JSONValue, Error>? {
        guard needed else { return nil }
        do { return .success(try await read(method, args: args)) } catch { return .failure(error) }
    }
    private func refresh(_ scope: NativeRefreshScope = .all) async throws {
        let version = revision, fm = financeMonth, cm = calendarMonth
        let y = Int(fm.prefix(4)) ?? 2026, m = Int(fm.suffix(2)) ?? 1
        async let lifeResult = fetchPart("getLifeData", args: [.string(cm)], needed: scope.contains(.life))
        async let financeResult = fetchPart("getFinanceOverview", args: [.int(y), .int(m)], needed: scope.contains(.finance))
        let (l, f) = await (lifeResult, financeResult)
        guard version == revision, fm == financeMonth, cm == calendarMonth else { throw CancellationError() }
        var next = state, failure: Error?, changed = false, financeChanged = false
        if let l {
            do {
                let value = try l.get().object
                guard case .array? = value["tasks"] else { throw Message(text: "Elenco attività non compatibile.") }
                let legacy = next.life.records("health")
                next.life = value
                if !legacy.isEmpty { next.life["health"] = .array(legacy.map(JSONValue.object)) }
                for write in next.pending where write.method != "saveHealthEntry" && LocalLifeMutation.supports(write.method) { try LocalLifeMutation.apply(write.method, write.payload, to: &next.life) }
                next.calendarMonth = cm; next.lifeRefreshedAt = Date(); changed = true
            } catch { failure = error }
        }
        if let f {
            do {
                let value = try f.get().object
                _ = try NativeValidation.financeResponse(.object(value))
                guard case .array? = value.record("extraPlan")["allocations"] else { throw Message(text: "Piano finanziario non compatibile.") }
                // Preserve cached charts for this month until the optional analysis refresh finishes.
                var merged = state.financeMonth == fm ? next.finance : [:]
                merged.merge(value) { _, new in new }
                next.finance = merged; next.plan = value.record("extraPlan"); next.financeMonth = fm; next.financeRefreshedAt = Date()
                changed = true; financeChanged = true
            } catch { failure = failure ?? error }
        }
        if changed { next.refreshedAt = Date(); next.imported = false; try save(next) }
        if financeChanged { financeGeneration += 1 }
        if let failure { throw failure }
    }
    func loadFinancePlans() async {
        do { while plansBusy { try await Task.sleep(nanoseconds: 100_000_000) } }
        catch { return }
        guard !Task.isCancelled else { return }
        plansBusy = true; plansError = nil
        defer { plansBusy = false }
        let version = revision, month = financeMonth
        do {
            if isDemo {
                var next = state
                NativePlanDemo.project(month: month, state: &next)
                try save(next); return
            }
            guard server != nil else { throw Message(text: "Collega Life OS per creare e sincronizzare i piani.") }
            let response = try await read("getFinancePlans", args: [.string(month)])
            try Task.checkCancellation()
            guard version == revision, month == financeMonth else { return }
            guard response.object.integer("version") == 2, response.object.text("month") == month,
                  case .array? = response.object["plans"], case .array? = response.object["payments"] else {
                throw Message(text: "Il server deve essere aggiornato al nuovo sistema Piani. I piani precedenti sono conservati.")
            }
            var next = state; next.finance["plansV2"] = response; try save(next)
        } catch is CancellationError {} catch {
            guard version == revision, month == financeMonth else { return }
            plansError = "Piani non aggiornati. " + error.localizedDescription
        }
    }
    func loadAnalysis() async {
        guard !isDemo, server != nil else { return }
        do { while analysisBusy { try await Task.sleep(nanoseconds: 100_000_000) } }
        catch { return }
        guard analysisGeneration != financeGeneration || state.financeMonth != financeMonth, !Task.isCancelled else { return }
        analysisBusy = true; defer { analysisBusy = false }
        do {
            while busy || syncing { try await Task.sleep(nanoseconds: 100_000_000) }
            let version = revision, generation = financeGeneration, month = financeMonth
            // Seed/classify categories in its own bounded request before analytics.
            _ = try await read("getFinanceCategoryOptions")
            try Task.checkCancellation()
            let result = try await read("getFinanceData", args: [.int(Int(month.prefix(4)) ?? 2026), .int(Int(month.suffix(2)) ?? 1)])
            try Task.checkCancellation()
            guard version == revision, generation == financeGeneration, month == financeMonth else { return }
            _ = try NativeValidation.financeResponse(result)
            var next = state; next.finance = result.object; next.financeMonth = month; next.financeRefreshedAt = Date(); try save(next)
            analysisGeneration = generation
        } catch is CancellationError {} catch {
            if (error as? URLError)?.code == .cancelled { return }
            if !NativeSyncPolicy.isTransient(error) { notice = "Analisi non aggiornata. Puoi riprovare dalla schermata Finanza." }
        }
    }
    var analysisIsCurrent: Bool { isDemo || (analysisGeneration == financeGeneration && state.financeMonth == financeMonth) }
    func sync(automatic: Bool = false, writeTriggered: Bool = false, scope: NativeRefreshScope = .all) async {
        if isDemo { rollover(); return }
        guard server != nil, !busy, !syncing else { return }
        if automatic, !writeTriggered, Date().timeIntervalSince(lastAutomaticSync) < 25 { return }
        syncing = true; error = nil; syncStatus = "Sincronizzazione…"; defer { syncing = false }
        var pendingScope = scope
        for write in transferablePending { pendingScope.formUnion(NativeSyncPolicy.scope(for: write.method)) }
        do {
            // The destination is persisted before writes. Stable UUIDs make a later retry safe.
            // No full read before sending: it doubled latency and prevented offline queues draining.
            try preserveLegacyMeasurements()
            var attempted = Set<String>()
            var blockedKeys = Set<String>()
            var writeFailure: Error?
            while let write = transferablePending.first(where: { !$0.accepted && !attempted.contains($0.id) }) {
                attempted.insert(write.id)
                let key = LocalLifeMutation.key(write)
                if blockedKeys.contains(key) { continue }
                pendingScope.formUnion(NativeSyncPolicy.scope(for: write.method))
                do {
                    let result = try await read(write.method, args: [.object(write.payload)])
                    let accepted = write.method == "saveExtra" ? result.object.integer("row") > 0 : result == .bool(true)
                    guard accepted else { throw Message(text: "Il server non ha confermato la modifica. La coda è conservata.") }
                    var next = state
                    if let index = next.pending.firstIndex(where: { $0.id == write.id }) { next.pending[index].accepted = true }
                    try save(next)
                } catch {
                    writeFailure = writeFailure ?? error
                    blockedKeys.insert(key)
                    if NativeSyncPolicy.isTransient(error) || [401, 403].contains((error as? NativeRequestRejected)?.status ?? 0) { break }
                    // A rejected health/routine setter must not block financial writes.
                }
            }
            try await refresh(pendingScope)
            var next = state; next.pending.removeAll { $0.accepted && $0.method != "saveHealthEntry" }; try save(next)
            lastAutomaticSync = Date()
            if let writeFailure { throw writeFailure }
            syncStatus = transferablePending.isEmpty ? "Aggiornato" : "Modifiche sul dispositivo · in attesa di invio"; notice = transferablePending.isEmpty ? nil : syncStatus
            if !transferablePending.isEmpty { scheduleSync() }
        } catch is CancellationError { lastAutomaticSync = Date(); syncStatus = "Aggiornamento sospeso" }
        catch {
            lastAutomaticSync = Date()
            if NativeSyncPolicy.isTransient(error) {
                syncStatus = state.pending.isEmpty ? "Dati salvati · riprovo al prossimo aggiornamento" : "Modifiche sul dispositivo · in attesa di rete"
                notice = syncStatus
            } else {
                syncStatus = "Accesso o verifica richiesta"
                if automatic { notice = error.localizedDescription } else { self.error = error.localizedDescription }
            }
        }
    }
    func perform(_ method: String, _ payload: Record = [:], args: [JSONValue]? = nil) async throws {
        error = nil
        if isDemo {
            var next = state
            try DemoActions.apply(method, payload, args: args, state: &next)
            next.refreshedAt = Date(); try save(next); return
        }
        try NativeServerFeaturePolicy.validate(method, payload: payload, life: life)
        if LocalLifeMutation.supports(method) {
            guard server != nil else { throw Message(text: "Collega il server per sincronizzare le modifiche.") }
            var next = state
            try LocalLifeMutation.apply(method, payload, to: &next.life)
            next.pending.append(PendingWrite(id: UUID().uuidString, method: method, payload: payload))
            try save(next)
            notice = "Salvato sul dispositivo · sincronizzazione in attesa"
            scheduleSync()
            return
        }
        guard !busy else { throw Message(text: "Attendi la fine del salvataggio.") }
        if method == "saveTransaction" || method == "saveExtra" {
            guard server != nil else { throw Message(text: "Per nuovi movimenti collega Life OS oppure apri la demo.") }
            var p = payload
            let id = p.text("requestId", fallback: UUID().uuidString); p["requestId"] = .string(id)
            var next = state
            if !next.pending.contains(where: { $0.id == id }) { next.pending.append(PendingWrite(id: id, method: method, payload: p)) }
            try save(next)
            notice = "Salvato sul dispositivo."
            scheduleSync(); return
        }
        guard server != nil else { throw Message(text: "Questo snapshot è consultabile. Per modificare attività e calendario usa la demo o collega Life OS.") }
        while syncing { try await Task.sleep(nanoseconds: 50_000_000) }
        guard !busy else { throw Message(text: "Attendi la fine del salvataggio.") }
        busy = true; defer { busy = false }
        // No automatic retry: these API methods do not all support request IDs.
        let result = try await read(method, args: args ?? [.object(payload)])
        guard result != .bool(false) else { throw Message(text: "Il server non ha confermato la modifica.") }
        do { try await refresh(NativeSyncPolicy.scope(for: method)) }
        catch { notice = "Operazione inviata. Aggiornamento non riuscito: sincronizza prima di ripetere l’azione." }
    }
    private func preserveLegacyMeasurements() throws {
        var next = state
        var copied = Set<String>()
        for write in next.pending where write.method == "saveHealthEntry" {
            do {
                try LocalLifeMutation.apply(write.method, write.payload, to: &next.life)
                copied.insert(write.id)
            } catch { /* Keep malformed legacy payloads in the backup, never send them. */ }
        }
        guard !copied.isEmpty else { return }
        next.pending.removeAll { copied.contains($0.id) }
        try save(next)
    }
    private func scheduleSync() {
        guard automaticallySyncsWrites, syncTask == nil else { return }
        syncTask = Task { [weak self] in
            guard let self else { return }
            while self.syncing || self.busy {
                do { try await Task.sleep(nanoseconds: 50_000_000) } catch { self.syncTask = nil; return }
            }
            var scope: NativeRefreshScope = []
            for write in self.transferablePending { scope.formUnion(NativeSyncPolicy.scope(for: write.method)) }
            await self.sync(automatic: true, writeTriggered: true, scope: scope.isEmpty ? .all : scope)
            self.syncTask = nil
            // Writes may arrive during the final read. Drain only after a successful sync;
            // failures wait for foreground/reachability/manual retry instead of spinning.
            if self.syncStatus == "Modifiche sul dispositivo · in attesa di invio" { self.scheduleSync() }
        }
    }
    func discardLocalWrite(_ id: String) async throws {
        guard !busy, !syncing, let write = state.pending.first(where: { $0.id == id }),
              !write.accepted, LocalLifeMutation.supports(write.method) else {
            throw Message(text: "Attendi la sincronizzazione. I movimenti finanziari non si annullano da qui.")
        }
        busy = true; defer { busy = false }
        // Read first: without a confirmed server snapshot we cannot safely undo locally.
        let fresh = try await read("getLifeData", args: [.string(calendarMonth)]).object
        guard case .array? = fresh["tasks"] else { throw Message(text: "Risposta server non compatibile.") }
        var next = state; next.pending.removeAll { $0.id == id }; next.life = fresh
        if let legacy = state.life["health"] { next.life["health"] = legacy }
        for pending in next.pending where pending.method != "saveHealthEntry" && LocalLifeMutation.supports(pending.method) {
            try LocalLifeMutation.apply(pending.method, pending.payload, to: &next.life)
        }
        try save(next)
        notice = "Modifica locale rimossa. Dati del server ripristinati."
    }
    func updateShiftCalendar(_ method: String, month: String) async throws -> Record {
        guard ["getShiftCalendar", "publishShiftCalendar", "rotateShiftCalendarLink"].contains(method),
              !isDemo, server != nil else { throw Message(text: "Collega prima il server Life OS.") }
        let mutates = method != "getShiftCalendar"
        if mutates {
            guard !busy, !syncing else { throw Message(text: "Attendi la fine del salvataggio e riprova.") }
            if method == "publishShiftCalendar", state.pending.contains(where: { $0.method == "paintShift" }) {
                throw Message(text: "Sincronizza prima i turni salvati sul dispositivo, poi pubblica il mese.")
            }
            busy = true
        }
        defer { if mutates { busy = false } }
        let version = revision
        let result = try await read(method, args: [.object(["month": .string(month)])])
        guard version == revision else { throw CancellationError() }
        guard case .object(let record) = result, record["path"] != nil, record["publishedAt"] != nil else {
            throw Message(text: "Il server non ha confermato il collegamento del calendario.")
        }
        return record
    }
    func run(_ method: String, _ payload: Record = [:], args: [JSONValue]? = nil) async {
        do { try await perform(method, payload, args: args) } catch { self.error = error.localizedDescription }
    }
    func shift(_ day: String) -> ShiftKind? { life.records("shifts").first { $0.text("day") == day }.flatMap { ShiftKind(rawValue: $0.text("kind")) } }
    func changeMonth(_ delta: Int, finance: Bool) async {
        guard !busy, !syncing else { return }
        if finance {
            let next = String(CivilDate.adding(delta, to: financeMonth + "-01", component: .month).prefix(7))
            guard next >= "2024-01", next <= "2035-12" else { return }
            financeMonth = next
        }
        else { calendarMonth = String(CivilDate.adding(delta, to: calendarMonth + "-01", component: .month).prefix(7)) }
        revision += 1
        if isDemo {
            var next = state; next.financeMonth = financeMonth; next.calendarMonth = calendarMonth
            do { try save(next) } catch { self.error = error.localizedDescription }
            return
        }
        await sync(scope: finance ? .finance : .life)
        // Keep the requested month on failure; never trap navigation at the last
        // successful snapshot or show its balances under a different month.
    }
    func expandedEvents(low: String, high: String, source: [Record]) -> [Record] {
        source.flatMap { event -> [Record] in
            CivilDate.occurrenceDays(start: event.text("day"), frequency: event.text("frequency"), until: event.text("until_day"), low: low, high: high).compactMap { day in
                var e = event; e["series_day"] = event["day"]; e["day"] = .string(day)
                let key = "\(event.integer("id")):\(day)"
                let status = life.record("occurrences").text(key, fallback: "open")
                if status == "skipped" { return nil }
                e["occurrence_status"] = .string(status); return e
            }
        }.sorted { ($0.text("day"), $0.text("start_time")) < ($1.text("day"), $1.text("start_time")) }
    }
    func loadWeather() async {
        guard !weatherBusy else { return }
        if let date = weatherDate, Date().timeIntervalSince(date) < 900 { return }
        if isDemo {
            weatherDetails = NativeWeather(temperature: 18, low: 12, high: 22, code: 0, change: "Nuvoloso dalle 18:00 · Demo")
            weatherDate = Date(); weather = "18° · Demo"; return
        }
        weatherBusy = true; defer { weatherBusy = false }
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=43.72&longitude=10.95&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&hourly=weather_code&forecast_days=2&timezone=Europe%2FRome") else { return }
        do {
            var request = URLRequest(url: url); request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let parsed = NativeWeather.parse(try JSONDecoder().decode(JSONValue.self, from: data).object) else { throw URLError(.badServerResponse) }
            weatherDetails = parsed; weatherDate = Date(); weather = "\(Int(parsed.temperature.rounded()))°"
        } catch { weather = "Meteo non disponibile" }
    }
}
