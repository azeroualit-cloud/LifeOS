import SwiftUI

struct NativeShiftBadge: View {
    let shift: ShiftKind?
    var body: some View {
        Text(shift?.letter ?? " ").font(.caption2.weight(.bold))
            .foregroundStyle(shift == .night ? Color.black : Color.black.opacity(0.85))
            .frame(maxWidth: .infinity).frame(height: 20)
            .background(shift?.color ?? Color.clear, in: RoundedRectangle(cornerRadius: NativeDesign.badgeRadius))
            .padding(.horizontal, NativeDesign.Space.xs).accessibilityLabel(shift?.title ?? "Nessun turno")
    }
}
struct NativeDueBadge: View {
    let day: String
    private var title: String {
        if day == CivilDate.day() { return "Oggi" }
        if day == CivilDate.adding(1, to: CivilDate.day()) { return "Domani" }
        if day < CivilDate.day() { return "Scaduta · " + CivilDate.label(day) }
        return CivilDate.label(day)
    }
    private var urgent: Bool { day <= CivilDate.adding(1, to: CivilDate.day()) }
    var body: some View {
        NativeStatusBadge(title: title, symbol: urgent ? "exclamationmark.circle" : "calendar", tone: urgent ? .warning : .neutral)
    }
}
struct NativeSavingsRing: View {
    let progress: NativeSavingsProgress
    var hidden = false
    @State private var expanded = false
    var body: some View {
        Button { expanded = true } label: {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.13), lineWidth: 8)
                Circle().trim(from: 0, to: min(1, progress.reserved / progress.target)).stroke(NativeDesign.financialGreen.opacity(0.55), style: StrokeStyle(lineWidth: 8, lineCap: .butt)).rotationEffect(.degrees(-90))
                Circle().trim(from: min(1, progress.reserved / progress.target), to: max(0, min(1, progress.assets / progress.target))).stroke(NativeDesign.financialGreen, style: StrokeStyle(lineWidth: 8, lineCap: .butt)).rotationEffect(.degrees(-90))
                Text(hidden ? "•••• €" : progress.assets.euro).font(.subheadline.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1).padding(NativeDesign.Space.medium)
            }.frame(width: 116, height: 116)
        }.buttonStyle(NativePressStyle()).accessibilityLabel("Patrimonio e obiettivo di risparmio").accessibilityIdentifier("savings-ring").accessibilityValue(hidden ? "Importo nascosto" : progress.assets.euro)
        .sheet(isPresented: $expanded) {
            NavigationStack {
                List {
                    LabeledContent("Patrimonio totale", value: hidden ? "••••" : progress.assets.euro)
                    LabeledContent("Fondo emergenza coperto", value: hidden ? "••••" : progress.reserved.euro).foregroundStyle(NativeDesign.accent.opacity(0.7))
                    LabeledContent("Altri risparmi", value: hidden ? "••••" : progress.other.euro).foregroundStyle(NativeDesign.accent)
                    LabeledContent("Prossimo traguardo", value: hidden ? "••••" : progress.target.euro)
                    LabeledContent("Da risparmiare", value: hidden ? "••••" : progress.missing.euro)
                    LabeledContent("Al mese fino a dicembre", value: hidden ? "••••" : progress.monthly.euro)
                    Text("Il fondo emergenza è una parte del patrimonio. Il fondo e il traguardo sono impostazioni indipendenti e modificabili. Il risparmio mensile divide la cifra mancante per i mesi fino a dicembre, incluso quello corrente.").font(.caption).foregroundStyle(NativeDesign.secondary)
                }.modifier(NativeListAppearance()).navigationTitle("Risparmi").navigationBarTitleDisplayMode(.inline).toolbar { DoneButton() }
            }.presentationDetents([.medium, .large])
        }
    }
}
struct NativeTodayPanel: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var habitWidth = 124.0
    @ScaledMetric(relativeTo: .subheadline) private var habitHeight = 44.0
    @ScaledMetric(relativeTo: .title) private var weatherHeaderHeight = 42.0
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            NativeCard(material: true) {
                if !typeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                        timeBlock(context.date).frame(minWidth: 80, maxWidth: .infinity)
                        conditionBlock.frame(minWidth: 80, maxWidth: .infinity)
                        temperatureBlock.frame(minWidth: 80, maxWidth: .infinity)
                    }.fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                        timeBlock(context.date)
                        HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                            conditionBlock.frame(maxWidth: .infinity)
                            temperatureBlock.frame(maxWidth: .infinity)
                        }
                    }
                }
                Text(store.weather == "Meteo non disponibile" ? "Meteo non disponibile" : store.weatherDetails?.change ?? "Carico il meteo…")
                    .font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                if let date = store.weatherDate, context.date.timeIntervalSince(date) > 1800 { Text("Meteo aggiornato alle " + date.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(NativeDesign.secondary) }
                Divider()
                HStack {
                    Text("Abitudini").font(.caption.weight(.semibold)).foregroundStyle(NativeDesign.secondary)
                    Spacer()
                    NavigationLink("Gestisci") { RoutinesEditor() }.font(.caption)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(store.todayRoutines.map { DisplayRecord($0) }) { item in
                            Button { Task { await store.run("setRoutineCheck", ["id": .int(item.value.integer("id")), "day": .string(CivilDate.day()), "checked": .bool(!item.value.flag("checked"))]) } } label: {
                                HStack(spacing: NativeDesign.Space.small) {
                                    Image(systemName: item.value.flag("checked") ? "checkmark.circle" : "circle")
                                    Text(item.value.text("title")).lineLimit(1)
                                }.font(.subheadline.weight(.medium)).frame(width: habitWidth, height: habitHeight)
                            }.modifier(NativeRoutineAppearance()).foregroundStyle(NativeDesign.accent).disabled(store.busy)
                                .accessibilityLabel(item.value.text("title"))
                                .accessibilityValue(item.value.flag("checked") ? "Completata" : "Da completare")
                                .accessibilityAddTraits(item.value.flag("checked") ? .isSelected : [])
                        }
                    }
                }
                if let active = activeShift(context.date) {
                    Divider()
                    HStack(spacing: NativeDesign.Space.medium) {
                        ZStack {
                            Circle().stroke(active.0.color.opacity(0.16), lineWidth: 5)
                            Circle().trim(from: 0, to: active.1).stroke(active.0.color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                            Image(systemName: active.0.symbol).foregroundStyle(active.0.color)
                        }.frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { Text(active.0.title + " in corso").font(.subheadline); Text("\(Int(active.1 * 100))% · " + active.0.time).font(.caption).foregroundStyle(NativeDesign.secondary) }
                    }
                }
            }
        }.task { await store.loadWeather() }
    }
    private func timeBlock(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text(CivilDate.label(CivilDate.day(date))).font(NativeDesign.heading).fixedSize(horizontal: false, vertical: true)
            Text("Empoli").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
            if let next = nextTime(date) {
                Text(next).font(.system(.title2, weight: .semibold)).monospacedDigit().accessibilityLabel(next)
            }
        }.padding(.vertical, NativeDesign.Space.small).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
    }
    private var conditionBlock: some View {
        VStack(spacing: NativeDesign.Space.small) {
            Image(systemName: weatherSymbol).symbolVariant(.fill).symbolRenderingMode(.multicolor)
                .font(.largeTitle.weight(.medium)).frame(height: weatherHeaderHeight)
            Text(store.weatherDetails.map { NativeWeather.group($0.code) } ?? "Meteo")
                .font(NativeDesign.body).multilineTextAlignment(.center)
            Text("Adesso").font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
        }.padding(.vertical, NativeDesign.Space.small).frame(maxWidth: .infinity, minHeight: 112, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, NativeDesign.Space.xs).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier("today-condition")
    }
    private var temperatureBlock: some View {
        VStack(spacing: NativeDesign.Space.small) {
            Text(store.weatherDetails.map { "\(Int($0.temperature.rounded()))°" } ?? "—")
                .font(NativeDesign.value).monospacedDigit().frame(height: weatherHeaderHeight)
            if let weather = store.weatherDetails {
                Text("min \(Int(weather.low.rounded()))°").font(NativeDesign.metadata)
                Text("max \(Int(weather.high.rounded()))°").font(NativeDesign.metadata)
            } else { Text("Non disponibile").font(NativeDesign.metadata) }
        }.foregroundStyle(Color.primary).padding(.vertical, NativeDesign.Space.small).frame(maxWidth: .infinity, minHeight: 112, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, NativeDesign.Space.xs).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier("today-temperature")
    }
    private var weatherSymbol: String {
        guard let code = store.weatherDetails?.code else { return "cloud" }
        switch code {
        case 0: return "sun.max"
        case 1...3: return "cloud"
        case 4...49: return "cloud.fog"
        case 50...69: return "cloud.rain"
        case 70...79: return "cloud.snow"
        case 80...94: return "cloud.heavyrain"
        default: return "cloud.bolt.rain"
        }
    }
    private func nextTime(_ now: Date) -> String? {
        let parts = CivilDate.calendar.dateComponents([.hour, .minute], from: now)
        let clock = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        // Sunrise is an astronomical marker, not one of the five daily times.
        let today = SolarTimes.calculate(CivilDate.day(now)).enumerated().filter { $0.offset != 1 }.map { $0.element.1 }
        return today.first { $0 != "—" && $0 > clock } ?? SolarTimes.calculate(CivilDate.adding(1, to: CivilDate.day(now))).first?.1
    }
    private func activeShift(_ now: Date) -> (ShiftKind, Double)? {
        let day = CivilDate.day(now), minutes = CivilDate.calendar.component(.hour, from: now) * 60 + CivilDate.calendar.component(.minute, from: now)
        if minutes < 360, store.shift(CivilDate.adding(-1, to: day)) == .night { return (.night, Double(minutes + 120) / 480) }
        guard let shift = store.shift(day) else { return nil }
        let start: Int
        switch shift { case .morning: start = 360; case .afternoon: start = 840; case .night: start = 1320; default: return nil }
        guard minutes >= start, minutes < start + 480 else { return nil }
        return (shift, Double(minutes - start) / 480)
    }
}

struct NativeCategoryChart: View {
    let rows: [Record]
    private func color(_ name: String) -> Color {
        // Explicit exception for category composition: the ring and its legend use
        // the same distinct swatches. Financial direction keeps its existing colours.
        if name == "Altre categorie" { return Color.secondary }
        let palette: [Color] = [.blue, .orange, .teal, .purple, .pink, .indigo]
        let rank = compact.firstIndex { $0.text("name") == name } ?? 0
        return palette[rank % palette.count]
    }

    private var compact: [Record] {
        if rows.count <= 6 { return rows }
        return Array(rows.prefix(5)) + [["name": .string("Altre categorie"), "amount": .number(rows.dropFirst(5).reduce(0) { $0 + $1.amount("amount") })]]
    }
    var body: some View {
        let total = rows.reduce(0) { $0 + $1.amount("amount") }
        HStack(spacing: NativeDesign.Space.large) {
            ZStack {
                ForEach(Array(compact.enumerated()), id: \.offset) { index, row in
                    let start = compact.prefix(index).reduce(0) { $0 + $1.amount("amount") } / max(Double.leastNonzeroMagnitude, total)
                    Circle().trim(from: start, to: min(1, start + row.amount("amount") / max(Double.leastNonzeroMagnitude, total)))
                        .stroke(color(row.text("name")), style: StrokeStyle(lineWidth: 18, lineCap: .butt)).rotationEffect(.degrees(-90))
                }
                Text(total.euro).font(.caption.weight(.semibold)).minimumScaleFactor(0.5).lineLimit(1).padding(NativeDesign.Space.medium)
            }.frame(width: 108, height: 108).padding(NativeDesign.Space.small).accessibilityLabel("Spese totali " + total.euro)
            VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
                ForEach(Array(compact.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                        Circle().fill(color(row.text("name"))).frame(width: 6, height: 6)
                        Text(row.text("name")).lineLimit(2)
                        Spacer(minLength: 2)
                        Text("\(Int((row.amount("amount") / max(Double.leastNonzeroMagnitude, total) * 100).rounded()))%").monospacedDigit()
                    }.font(.caption2)
                }
            }.frame(maxWidth: .infinity)
        }.padding(.vertical, NativeDesign.Space.small)
        DisclosureGroup("Tutte le categorie") {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LabeledContent {
                    Text(row.amount("amount").euro).monospacedDigit()
                } label: {
                    HStack(spacing: NativeDesign.Space.small) {
                        Circle().fill(compact.contains { $0.text("name") == row.text("name") } ? color(row.text("name")) : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(row.text("name"))
                    }
                }.font(.subheadline)
            }
        }.font(.subheadline)
    }
}
