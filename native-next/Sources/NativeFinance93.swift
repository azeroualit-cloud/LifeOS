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
        var spent: [String: Double] = [:]
        for row in categories {
            let value = row.amount("amount"), name = row.text("name", fallback: "Altro")
            if value > 0 { spent[name, default: 0] += value }
        }
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
        return result
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
    private var parts: [Double] {
        let values = categories.map { $0.amount("amount") }.filter { $0 > 0 }.sorted(by: >)
        let head = Array(values.prefix(3))
        let rest = max(0, spent - head.reduce(0, +))
        return rest > 0.005 ? head + [rest] : head
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
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(NativeDesign.barTrack)
                HStack(spacing: NativeDesign.Space.xxs) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        Rectangle().fill(NativeDesign.financeBudget[min(index, NativeDesign.financeBudget.count - 1)])
                            .frame(width: max(0, width * CGFloat(min(value, scale) / scale) - NativeDesign.Space.xxs))
                    }
                }
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
    @State private var selected: String?
    @ScaledMetric(relativeTo: .body) private var mapHeight: CGFloat = 220

    private var items: [NativeSalaryItem] { NativeSalaryMap.items(summary: summary, categories: categories) }
    var body: some View {
        let items = items
        let salary = NativeSalaryMap.salary(summary: summary, items: items)
        VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Dove va lo stipendio").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Spacer(minLength: NativeDesign.Space.small)
                Text(hidden ? "••••" : salary.euro).font(.subheadline).monospacedDigit().foregroundStyle(NativeDesign.secondary)
            }
            if items.isEmpty {
                Text("Nessun dato del mese").font(.subheadline).foregroundStyle(NativeDesign.secondary)
            } else {
                VStack(alignment: .leading, spacing: NativeDesign.Space.medium) {
                    map(items, salary: salary)
                    legend(items, salary: salary)
                    if let item = items.first(where: { $0.id == selected }) { detail(item, items: items, salary: salary) }
                }
                .padding(.horizontal, NativeDesign.Layout.compactCardInset).padding(.vertical, NativeDesign.Layout.cardInsetVertical)
                .loCardSurface()
            }
        }
        .accessibilityIdentifier("finance-salary-map")
    }
    private func map(_ items: [NativeSalaryItem], salary: Double) -> some View {
        GeometryReader { proxy in
            let tiles = NativeSalaryMap.tiles(items, in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                ForEach(tiles, id: \.item.id) { tile in
                    tileView(tile.item, rect: tile.rect, salary: salary, largest: items.filter { $0.group == tile.item.group }.map(\.value).max() ?? 1)
                }
            }
        }
        .frame(height: mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous))
    }
    private func tileView(_ item: NativeSalaryItem, rect: CGRect, salary: Double, largest: Double) -> some View {
        let on = selected == item.id
        let big = rect.width > 52 && rect.height > 38
        let mid = !big && rect.width > 34 && rect.height > 20
        let color = NativeDesign.financeGroups[min(item.group, NativeDesign.financeGroups.count - 1)]
        return Button { selected = on ? nil : item.id } label: {
            VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                if big || mid { Text(item.name).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }
                if big && !hidden { Text(NativeSalaryMap.percent(item.value, of: salary)).font(.caption2).monospacedDigit() }
            }
            .foregroundStyle(NativeDesign.financeTileText)
            .padding(NativeDesign.Space.xs)
            .frame(width: max(0, rect.width - 1), height: max(0, rect.height - 1), alignment: .topLeading)
            .background(color.opacity(on ? 1 : 0.72 + 0.28 * item.value / max(largest, 0.01)))
            .overlay { if on { Rectangle().strokeBorder(Color.white, lineWidth: NativeDesign.Layout.selectionLine) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityLabel(NativeSalaryMap.groupTitles[item.group] + ", " + item.name + (hidden ? "" : ": " + item.value.euro + ", " + NativeSalaryMap.percent(item.value, of: salary) + " dello stipendio"))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("finance-salary-tile-" + item.name)
    }
    private func legend(_ items: [NativeSalaryItem], salary: Double) -> some View {
        let groups = Array(Set(items.map(\.group))).sorted()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: NativeDesign.Space.medium) { ForEach(groups, id: \.self) { chip($0, items: items, salary: salary) } }
            VStack(alignment: .leading, spacing: NativeDesign.Space.xs) { ForEach(groups, id: \.self) { chip($0, items: items, salary: salary) } }
        }
    }
    private func chip(_ group: Int, items: [NativeSalaryItem], salary: Double) -> some View {
        let total = items.filter { $0.group == group }.reduce(0) { $0 + $1.value }
        return HStack(spacing: NativeDesign.Space.xs) {
            Circle().fill(NativeDesign.financeGroups[min(group, 3)]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
            Text(NativeSalaryMap.groupTitles[group]).foregroundStyle(NativeDesign.secondary)
            if !hidden { Text(NativeSalaryMap.percent(total, of: salary)).fontWeight(.semibold).monospacedDigit() }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }
    private func detail(_ item: NativeSalaryItem, items: [NativeSalaryItem], salary: Double) -> some View {
        let siblings = items.filter { $0.group == item.group && $0.id != item.id }
        let rows = item.rows.isEmpty ? [NativeSalaryRow(label: item.name, value: item.value)] : item.rows
        let color = NativeDesign.financeGroups[min(item.group, 3)]
        return VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            HStack(alignment: .top, spacing: NativeDesign.Space.small) {
                Circle().fill(color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small).padding(.top, NativeDesign.Space.xs)
                VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
                    Text(item.name).font(.headline)
                    Text(NativeSalaryMap.groupTitles[item.group]).font(.caption).foregroundStyle(NativeDesign.secondary)
                }
                Spacer(minLength: NativeDesign.Space.small)
                VStack(alignment: .trailing, spacing: NativeDesign.Space.xxs) {
                    Text(hidden ? "••••" : item.value.euro).font(.headline).monospacedDigit()
                    if !hidden { Text(NativeSalaryMap.percent(item.value, of: salary) + " dello stipendio").font(.caption).foregroundStyle(NativeDesign.secondary) }
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label).foregroundStyle(NativeDesign.secondary)
                    Spacer()
                    Text(hidden ? "••••" : row.value.euro).monospacedDigit()
                }.font(.subheadline)
            }
            if !siblings.isEmpty {
                Text("Altre voci di " + NativeSalaryMap.groupTitles[item.group]).font(.caption).foregroundStyle(NativeDesign.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NativeDesign.Space.small) {
                        ForEach(siblings) { other in
                            Button { selected = other.id } label: {
                                HStack(spacing: NativeDesign.Space.xs) {
                                    Circle().fill(color).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small)
                                    Text(other.name + (hidden ? "" : " · " + other.value.euro)).font(.footnote.weight(.medium))
                                }
                                .padding(.horizontal, NativeDesign.Space.medium)
                                .frame(minHeight: NativeDesign.Layout.touchTarget)
                                .loTileSurface(capsule: true)
                            }
                            .buttonStyle(NativePressStyle())
                        }
                    }
                }
            }
        }
        .padding(.top, NativeDesign.Space.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finance-salary-detail")
    }
}
