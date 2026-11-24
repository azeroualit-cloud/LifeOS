import SwiftUI

/// Build 93 Finanza – Panoramica (BUILD93-PREVIEW-FINAL-2026-11-21, FINANCE-PALETTE-2026-11-21).
/// Pure data first (tested), then the views.
struct NativeSalaryItem: Equatable, Identifiable {
    let name: String
    let group: Int
    let value: Double
    var rows: [NativeSalaryRow] = []
    var id: String { String(group) + "|" + name }
}
struct NativeSalaryRow: Equatable { let label: String; let value: Double }

enum NativeSalaryMap {
    static let groupTitles = ["Impegni del mese", "Messo da parte", "Speso", "Libero"]
    private static let savingWords = ["accanton", "risparm", "fondo", "messo da parte"]

    static func isSaving(_ name: String) -> Bool {
        let lower = name.lowercased()
        return savingWords.contains { lower.contains($0) }
    }

    /// Commitments and savings come from the monthly breakdown, spending from the month's
    /// categories (largest four, the rest as "Altro"), the free part from the remaining budget.
    static func items(summary: Record, categories: [Record]) -> [NativeSalaryItem] {
        var result: [NativeSalaryItem] = []
        for row in summary.records("monthlyBudgetBreakdown") {
            let value = row.amount("amount"), name = row.text("name")
            guard value > 0, !name.isEmpty else { continue }
            result.append(NativeSalaryItem(name: name, group: isSaving(name) ? 1 : 0, value: value))
        }
        // A commitment (rent, bills) paid this month also appears among the categories:
        // count it once, as a commitment (build 95, «Affitto» was shown twice).
        let committed = Set(result.map { $0.name.lowercased() })
        var spent: [String: Double] = [:]
        for row in categories {
            let value = row.amount("amount"), name = row.text("name", fallback: "Altro")
            if value > 0, !committed.contains(name.lowercased()) { spent[name, default: 0] += value }
        }
        // Spending never exceeds what the budget recorded as spent this month.
        let spentTotal = spent.values.reduce(0, +), recorded = summary.amount("monthlySpent")
        if recorded > 0, spentTotal > recorded { for key in spent.keys { spent[key] = (spent[key] ?? 0) / spentTotal * recorded } }
        let sorted = spent.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        let head = sorted.prefix(4), tail = sorted.dropFirst(4)
        for entry in head { result.append(NativeSalaryItem(name: entry.key, group: 2, value: entry.value)) }
        let rest = tail.reduce(0) { $0 + $1.value }
        if rest > 0 {
            result.append(NativeSalaryItem(name: "Altro", group: 2, value: rest,
                rows: tail.map { NativeSalaryRow(label: $0.key, value: $0.value) }))
        }
        let free = summary.amount("monthlyRemaining")
        if free > 0 { result.append(NativeSalaryItem(name: "Libero", group: 3, value: free, rows: [NativeSalaryRow(label: "Ancora da spendere", value: free)])) }
        return mergeSmall(result)
    }

    /// Entries under 2 % of the total join one «Altre voci» tile per group, listed in its detail,
    /// so the map has no tiny unnamed squares.
    static func mergeSmall(_ items: [NativeSalaryItem]) -> [NativeSalaryItem] {
        let total = items.reduce(0) { $0 + $1.value }
        guard total > 0 else { return items }
        var kept: [NativeSalaryItem] = []
        var small: [Int: [NativeSalaryItem]] = [:]
        for item in items {
            if item.value / total < 0.02 && item.name != "Libero" { small[item.group, default: []].append(item) } else { kept.append(item) }
        }
        for (group, list) in small.sorted(by: { $0.key < $1.key }) {
            if list.count == 1 { kept.append(list[0]); continue }
            let rows = list.flatMap { $0.rows.isEmpty ? [NativeSalaryRow(label: $0.name, value: $0.value)] : $0.rows }
            kept.append(NativeSalaryItem(name: "Altre voci", group: group, value: list.reduce(0) { $0 + $1.value }, rows: rows))
        }
        return kept
    }

    static func salary(summary: Record, items: [NativeSalaryItem]) -> Double {
        let declared = summary.amount("monthlySalary")
        return declared > 0 ? declared : items.reduce(0) { $0 + $1.value }
    }

    static func percent(_ value: Double, of salary: Double) -> String {
        guard salary > 0 else { return "" }
        let p = value / salary * 100
        return (p >= 10 ? String(Int(p.rounded())) : p.formatted(.number.precision(.fractionLength(1)))) + "%"
    }

    /// Squarified treemap: areas proportional to values, as close to squares as possible.
    static func squarify(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else { return values.map { _ in .zero } }
        let scale = Double(rect.width * rect.height) / total
        let areas = values.map { $0 * scale }
        var rects = [CGRect](repeating: .zero, count: values.count)
        var free = rect
        var row: [Int] = []
        func worst(_ indexes: [Int], side: Double) -> Double {
            let sum = indexes.reduce(0) { $0 + areas[$1] }
            guard sum > 0, side > 0 else { return .infinity }
            let largest = indexes.map { areas[$0] }.max() ?? 0
            let smallest = indexes.map { areas[$0] }.min() ?? 0
            guard smallest > 0 else { return .infinity }
            return max(side * side * largest / (sum * sum), sum * sum / (side * side * smallest))
        }
        func layout() {
            let sum = row.reduce(0) { $0 + areas[$1] }
            guard sum > 0 else { row = []; return }
            if free.width >= free.height {
                let width = CGFloat(sum) / free.height
                var y = free.minY
                for index in row {
                    let height = CGFloat(areas[index]) / width
                    rects[index] = CGRect(x: free.minX, y: y, width: width, height: height); y += height
                }
                free = CGRect(x: free.minX + width, y: free.minY, width: max(0, free.width - width), height: free.height)
            } else {
                let height = CGFloat(sum) / free.width
                var x = free.minX
                for index in row {
                    let width = CGFloat(areas[index]) / height
                    rects[index] = CGRect(x: x, y: free.minY, width: width, height: height); x += width
                }
                free = CGRect(x: free.minX, y: free.minY + height, width: free.width, height: max(0, free.height - height))
            }
            row = []
        }
        for index in areas.indices where areas[index] > 0 {
            let side = Double(min(free.width, free.height))
            if row.isEmpty || worst(row + [index], side: side) <= worst(row, side: side) { row.append(index) }
            else { layout(); row.append(index) }
        }
        if !row.isEmpty { layout() }
        return rects
    }

    /// Group totals, largest first (main map of «Dove va lo stipendio»).
    static func groups(_ items: [NativeSalaryItem]) -> [(group: Int, total: Double)] {
        Dictionary(grouping: items, by: \.group).map { (group: $0.key, total: $0.value.reduce(0) { $0 + $1.value }) }
            .filter { $0.total > 0 }.sorted { $0.total == $1.total ? $0.group < $1.group : $0.total > $1.total }
    }
    /// Layout values with a floor, so a tiny share still gets a tile wide enough for its name.
    static func floored(_ values: [Double], minShare: Double) -> [Double] {
        let total = values.reduce(0, +)
        guard total > 0 else { return values }
        return values.map { $0 > 0 ? max($0, total * minShare) : 0 }
    }
    /// Groups laid out first (largest first), then each group's items inside its rectangle.
    static func tiles(_ items: [NativeSalaryItem], in rect: CGRect) -> [(item: NativeSalaryItem, rect: CGRect)] {
        let groups = Dictionary(grouping: items, by: \.group)
            .map { (group: $0.key, items: $0.value.sorted { $0.value > $1.value }, total: $0.value.reduce(0) { $0 + $1.value }) }
            .sorted { $0.total > $1.total }
        let groupRects = squarify(groups.map(\.total), in: rect)
        var result: [(item: NativeSalaryItem, rect: CGRect)] = []
        for (index, group) in groups.enumerated() {
            let inner = squarify(group.items.map(\.value), in: groupRects[index])
            for (offset, item) in group.items.enumerated() { result.append((item, inner[offset])) }
        }
        return result
    }
}

/// Budget hero: remaining, per day, spent split by category, month progress.
struct NativeBudgetHero93: View {
    let summary: Record
    let categories: [Record]
    let month: String
    let hidden: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = NativeDesign.Layout.budgetAmount

    private var overview: NativeFinanceOverview { NativeFinanceOverview(summary: summary, month: month) }
    private var spent: Double { max(0, summary.amount("monthlySpent")) }
    private var total: Double { spent + max(0, summary.amount("monthlyRemaining")) }
    /// Up to four shares of what was spent, scaled so that together they equal `spent`.
    private var parts: [Double] {
        let values = categories.map { $0.amount("amount") }.filter { $0 > 0 }.sorted(by: >)
        let sum = values.reduce(0, +)
        guard sum > 0, spent > 0 else { return spent > 0 ? [spent] : [] }
        let scaled = values.map { $0 / sum * spent }
        let head = Array(scaled.prefix(3)), rest = scaled.dropFirst(3).reduce(0, +)
        return rest > 0.005 ? head + [rest] : head
    }
    /// Today's share of the month, for the marker on the bar (nil outside the current month).
    private var dayShare: Double? {
        let today = CivilDate.day()
        guard String(today.prefix(7)) == month else { return nil }
        let count = CivilDate.calendar.range(of: .day, in: .month, for: CivilDate.date(month + "-01"))?.count ?? 30
        return Double(Int(today.suffix(2)) ?? 1) / Double(count)
    }
    private var dayLabel: String {
        let today = CivilDate.day()
        guard String(today.prefix(7)) == month else { return CivilDate.monthTitle(month) }
        let count = CivilDate.calendar.range(of: .day, in: .month, for: CivilDate.date(month + "-01"))?.count ?? 30
        return "giorno " + String(Int(today.suffix(2)) ?? 1) + " di " + String(count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text("Budget rimanente").font(.subheadline.weight(.semibold)).foregroundStyle(NativeDesign.financeTitle)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.medium) { amount; Spacer(minLength: 0); daily }
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { amount; daily }
            }
            bar
            HStack {
                Text(hidden ? "speso ••••" : "speso " + spent.euro + " di " + total.euro)
                Spacer(minLength: NativeDesign.Space.small)
                if dayShare != nil {
                    Capsule().fill(NativeDesign.financePace)
                        .frame(width: NativeDesign.Space.medium, height: NativeDesign.Space.small).accessibilityHidden(true)
                }
                Text(dayLabel)
            }
            .font(.footnote).monospacedDigit().foregroundStyle(NativeDesign.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, NativeDesign.Layout.compactCardInset).padding(.vertical, NativeDesign.Layout.cardInsetVertical)
        .loCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("budget-hero")
    }
    private var amount: some View {
        Group {
            if hidden { Text("•••• €") }
            else if let remaining = overview.remaining { Text(remaining.euro).modifier(NativeNumericFeedback(value: remaining)) }
            else { Text("Da aggiornare") }
        }
        .font(NativeDesign.budgetValue(size: amountSize)).monospacedDigit()
        .minimumScaleFactor(0.7).lineLimit(1)
        .accessibilityIdentifier("finance-budget-value")
    }
    @ViewBuilder private var daily: some View {
        if !hidden, overview.remaining != nil, overview.days > 0 {
            Text(overview.daily.euro + " al giorno").font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }
    private var bar: some View {
        let values = parts
        let scale = max(total, 0.01)
        let marker = dayShare
        return GeometryReader { proxy in
            let width = proxy.size.width
            let gap = NativeDesign.Space.xxs
            ZStack(alignment: .leading) {
                Capsule().fill(NativeDesign.barTrack)
                // REVIEW-95C: the month gone by as a soft band under the spending, instead of a hairline marker:
                // spending past the band = ahead of the month, inside it = behind.
                if let marker {
                    Capsule().fill(NativeDesign.financePace)
                        .frame(width: max(NativeDesign.Space.medium, width * CGFloat(min(max(marker, 0), 1))))
                        .accessibilityHidden(true)
                }
                HStack(spacing: gap) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        Rectangle().fill(NativeDesign.financeBudget[min(index, NativeDesign.financeBudget.count - 1)])
                            .frame(width: max(0, (width - gap * CGFloat(values.count)) * CGFloat(min(value, scale) / scale)))
                    }
                }
                .frame(width: width, alignment: .leading)
                .clipShape(Capsule())
            }
        }
        .frame(height: NativeDesign.Space.medium)
        .accessibilityElement()
        .accessibilityLabel(hidden ? "Budget del mese" : "Budget del mese " + total.euro + ": speso " + spent.euro)
    }
}

/// "Dove va lo stipendio": treemap by group, tap for detail and other items of the same group.
struct NativeSalaryMapCard: View {
    let summary: Record
    let categories: [Record]
    let hidden: Bool
    @State private var openGroup: Int?
    @ScaledMetric(relativeTo: .body) private var mapHeight: CGFloat = 200

    private var items: [NativeSalaryItem] { NativeSalaryMap.items(summary: summary, categories: categories) }
    var body: some View {
        let items = items
        let salary = NativeSalaryMap.salary(summary: summary, items: items)
        let groups = NativeSalaryMap.groups(items)
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dove va lo stipendio").font(.headline.bold()).accessibilityAddTraits(.isHeader)
                Spacer(minLength: NativeDesign.Space.small)
                Text(hidden ? "••••" : salary.euro).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
            }
            if items.isEmpty {
                Text("Nessun dato del mese").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    // SALARY-MAP-COLORS-2026-11-23: one coloured tile per group; a tap opens the group's own map.
                    NativeSalaryTreemap(entries: groups.map { group in
                        NativeSalaryTreemap.Entry(id: "group-" + String(group.group), title: NativeSalaryMap.groupTitles[group.group], value: group.total, group: group.group)
                    }, salary: salary, hidden: hidden, height: mapHeight) { entry in openGroup = entry.group }
                    Text("Tocca un gruppo per vedere le sue voci.").font(.footnote).foregroundStyle(NativeDesign.secondary)
                }
                .padding(.horizontal, NativeDesign.Layout.compactCardInset).padding(.vertical, NativeDesign.Layout.cardInsetVertical)
                .loCardSurface()
            }
        }
        .accessibilityIdentifier("finance-salary-map")
        .sheet(item: Binding(get: { openGroup.map(NativeSalaryGroupID.init) }, set: { openGroup = $0?.group })) { id in
            NativeSalaryGroupSheet(group: id.group, items: items.filter { $0.group == id.group }, salary: salary, hidden: hidden)
        }
    }
}
struct NativeSalaryGroupID: Identifiable { let group: Int; var id: Int { group } }

/// Treemap with readable labels: values below a minimum share are drawn larger so every tile shows
/// its name (SITE-PARITY-2026-11-22); the real percentage is always the one written.
struct NativeSalaryTreemap: View {
    struct Entry: Identifiable, Equatable { let id: String; let title: String; let value: Double; let group: Int }
    let entries: [Entry]
    let salary: Double
    let hidden: Bool
    let height: CGFloat
    var selected: String? = nil
    let open: (Entry) -> Void
    var body: some View {
        GeometryReader { proxy in
            let rects = NativeSalaryMap.squarify(NativeSalaryMap.floored(entries.map(\.value), minShare: 0.08), in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    tile(entry, rect: rects[index])
                }
            }
        }
        .frame(height: height)
    }
    private func tile(_ entry: Entry, rect: CGRect) -> some View {
        let big = rect.height > 52 && rect.width > 70
        let on = selected == entry.id
        let shape = RoundedRectangle(cornerRadius: NativeDesign.badgeRadius, style: .continuous)
        return Button { open(entry) } label: {
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                Text(entry.title).font(.footnote.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.75)
                if !hidden {
                    Text(NativeSalaryMap.percent(entry.value, of: salary)).font(.caption2.weight(.semibold)).monospacedDigit()
                    if big { Text(entry.value.euro).font(.caption2).monospacedDigit() }
                }
            }
            .foregroundStyle(NativeDesign.salaryGroupText[entry.group])
            .padding(NativeDesign.Space.small)
            .frame(width: max(0, rect.width - 2), height: max(0, rect.height - 2), alignment: .topLeading)
            .background(NativeDesign.salaryGroups[entry.group], in: shape)
            .overlay { if on { shape.strokeBorder(Color.primary, lineWidth: NativeDesign.Layout.selectionLine) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .offset(x: rect.minX + 1, y: rect.minY + 1)
        .accessibilityLabel(entry.title + (hidden ? "" : ": " + entry.value.euro + ", " + NativeSalaryMap.percent(entry.value, of: salary) + " dello stipendio"))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("finance-salary-tile-" + entry.title)
    }
}

/// The map of one group (site parity): its entries as tiles, the selected entry's composition and the full list.
struct NativeSalaryGroupSheet: View {
    let group: Int
    let items: [NativeSalaryItem]
    let salary: Double
    let hidden: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String?
    var body: some View {
        let sorted = items.sorted { $0.value > $1.value }
        let total = sorted.reduce(0) { $0 + $1.value }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NativeDesign.Space.large) {
                    HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.small) {
                        Circle().fill(NativeDesign.salaryGroups[group]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                        Text(hidden ? "••••" : total.euro).font(.title.bold()).monospacedDigit()
                        Spacer(minLength: NativeDesign.Space.small)
                        if !hidden { Text(NativeSalaryMap.percent(total, of: salary) + " dello stipendio").font(.subheadline).foregroundStyle(NativeDesign.secondary) }
                    }
                    NativeSalaryTreemap(entries: sorted.map { .init(id: $0.id, title: $0.name, value: $0.value, group: group) },
                                        salary: salary, hidden: hidden, height: 220, selected: selected) { entry in
                        selected = selected == entry.id ? nil : entry.id
                    }
                    LOListCard {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                            row(item, isLast: index == sorted.count - 1)
                        }
                    }
                    .accessibilityIdentifier("finance-salary-detail")
                }
                .padding(.horizontal, NativeDesign.Layout.screenInset).padding(.vertical, NativeDesign.Space.large)
            }
            .background(NativeDesign.canvas)
            .navigationTitle(NativeSalaryMap.groupTitles[group]).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
    private func row(_ item: NativeSalaryItem, isLast: Bool) -> some View {
        let open = selected == item.id
        return Button { selected = open ? nil : item.id } label: {
            LOListRow(isLast: isLast) {
                VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                    HStack {
                        Text(item.name).font(.subheadline.weight(open ? .semibold : .regular)).foregroundStyle(.primary)
                        Spacer(minLength: NativeDesign.Space.small)
                        Text(hidden ? "••••" : item.value.euro).font(.subheadline).monospacedDigit().foregroundStyle(.primary)
                    }
                    if open {
                        ForEach(Array(item.rows.enumerated()), id: \.offset) { _, line in
                            HStack {
                                Text(line.label)
                                Spacer()
                                Text(hidden ? "••••" : line.value.euro).monospacedDigit()
                            }.font(.footnote).foregroundStyle(NativeDesign.secondary)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NativePressStyle())
        .accessibilityAddTraits(open ? .isSelected : [])
    }
}
