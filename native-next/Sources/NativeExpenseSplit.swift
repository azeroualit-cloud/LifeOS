import SwiftUI

/// FUNDING-BLOCK-2026-11-21 / REVIEW-95: the user divides an ordinary expense between savings and
/// the budget, choosing the budget months (preview 93, «Nuova spesa» and «Bolletta con piano»).
/// The server records it with the existing 'recovery' policy: the budget part is charged in the
/// chosen months, the rest stays on savings. One bank movement.
struct NativeExpenseSplit: Equatable {
    /// Cents taken from savings.
    var savings = 0
    /// Budget months; empty means the month of the expense only.
    var months: [String] = []
    static let step = 500

    func budget(_ amount: Int) -> Int { max(0, amount - min(max(0, savings), amount)) }
    func chosenMonths(day: String) -> [String] { months.isEmpty ? [String(day.prefix(7))] : months.sorted() }
    func isCustom(day: String) -> Bool { savings > 0 || chosenMonths(day: day) != [String(day.prefix(7))] }
    /// Same rounding as the server: equal parts, the extra cents on the first months.
    func shares(_ amount: Int, day: String) -> [(month: String, cents: Int)] {
        let list = chosenMonths(day: day), total = budget(amount)
        guard !list.isEmpty else { return [] }
        return list.enumerated().map { index, month in (month, total / list.count + (index < total % list.count ? 1 : 0)) }
    }
    /// Extra fields of «saveTransaction»; nil keeps the plain monthly budget.
    func payload(amount: Int, day: String) -> Record? {
        guard isCustom(day: day), budget(amount) > 0 else { return nil }
        return ["budgetTreatment": .string("recovery"),
                "recoveryMonths": .string(chosenMonths(day: day).joined(separator: ", ")),
                "recoveryAmount": .number(Double(budget(amount)) / 100)]
    }
    /// BILL-PAST-MONTHS-2026-11-24: a bill's budget months start from the current month, never a past one.
    static func billDay(_ day: String) -> String { max(day, CivilDate.day()) }
    /// Default for a bill's excess: «Prossimi mesi», this month and the next two.
    static func forBill(day: String, savings: Int = 0) -> NativeExpenseSplit {
        let first = billDay(day)
        return NativeExpenseSplit(savings: savings, months: (0..<3).map { String(CivilDate.adding($0, to: String(first.prefix(7)) + "-01", component: .month).prefix(7)) })
    }
    /// The 12 months offered, from the month of the expense.
    static func offered(day: String) -> [String] { (0..<12).map { CivilDate.adding($0, to: String(day.prefix(7)) + "-01", component: .month).prefix(7).description } }
    mutating func toggle(_ month: String, day: String) {
        var set = Set(chosenMonths(day: day))
        if set.contains(month) { if set.count > 1 { set.remove(month) } } else if set.count < 12 { set.insert(month) }
        months = set.sorted()
    }
    mutating func change(_ delta: Int, amount: Int, allowsAll: Bool = false) {
        savings = min(max(0, savings + delta), max(0, allowsAll ? amount : amount - 1))
    }
}

/// Rows of the split under «Da dove arrivano i soldi»: savings with − / +, the budget for the rest,
/// and the budget months as chips with each month's share.
struct NativeExpenseSplitRows: View {
    @Binding var split: NativeExpenseSplit
    let amount: Int
    let day: String
    /// Plan payments: the uncovered part may stay entirely on savings (budget 0, no months).
    var allowsAll = false
    var savingsTitle = "Risparmi"
    /// Bills: the budget part goes to the competence months chosen below, so no month chips here.
    var showsMonths = true
    var budgetTitle = "Budget"
    var body: some View {
        let euro: (Int) -> String = { (Double($0) / 100).euro }
        HStack(spacing: NativeDesign.Space.small) {
            Circle().fill(NativeDesign.salaryGroups[1]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small).accessibilityHidden(true)
            Text(savingsTitle)
            Spacer(minLength: NativeDesign.Space.small)
            NativeIconButton(symbol: "minus", label: "Meno dai risparmi") { split.change(-NativeExpenseSplit.step, amount: amount, allowsAll: allowsAll) }
                .disabled(split.savings <= 0).accessibilityIdentifier("expense-split-less")
            Text(euro(min(split.savings, amount))).monospacedDigit().frame(minWidth: NativeDesign.Layout.actionCircle)
                .accessibilityIdentifier("expense-split-savings")
            NativeIconButton(symbol: "plus", label: "Più dai risparmi") { split.change(NativeExpenseSplit.step, amount: amount, allowsAll: allowsAll) }
                .disabled(split.savings >= (allowsAll ? amount : amount - 1)).accessibilityIdentifier("expense-split-more")
        }
        HStack(spacing: NativeDesign.Space.small) {
            Circle().fill(NativeDesign.salaryGroups[3]).frame(width: NativeDesign.Space.small, height: NativeDesign.Space.small).accessibilityHidden(true)
            Text(budgetTitle)
            Spacer(minLength: NativeDesign.Space.small)
            Text(euro(split.budget(amount))).monospacedDigit().accessibilityIdentifier("expense-split-budget")
        }
        if showsMonths && split.budget(amount) > 0 {
        VStack(alignment: .leading, spacing: NativeDesign.Space.small) {
            Text("Mesi in cui pesa sul budget").font(.footnote).foregroundStyle(NativeDesign.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NativeDesign.Space.small) {
                    let shares = Dictionary(uniqueKeysWithValues: split.shares(amount, day: day).map { ($0.month, $0.cents) })
                    ForEach(NativeExpenseSplit.offered(day: day), id: \.self) { month in
                        let on = shares[month] != nil
                        Button { split.toggle(month, day: day) } label: {
                            VStack(spacing: NativeDesign.Space.none) {
                                Text(CivilDate.monthAbbreviation(month)).font(.subheadline.weight(.semibold))
                                if let cents = shares[month] { Text(euro(cents)).font(.caption2).monospacedDigit() }
                            }
                            .foregroundStyle(on ? Color(uiColor: .systemBackground) : Color.primary)
                            .padding(.horizontal, NativeDesign.Space.medium)
                            .frame(minWidth: NativeDesign.Layout.actionCircle, minHeight: NativeDesign.Layout.touchTarget)
                            .background(Capsule().fill(on ? Color.primary : Color(uiColor: .tertiarySystemFill)))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(NativePressStyle())
                        .accessibilityLabel(CivilDate.monthTitle(month) + (shares[month].map { ", " + euro($0) } ?? ""))
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("expense-split-month-" + month)
                    }
                }
            }
        }
        .padding(.vertical, NativeDesign.Space.xs)
        }
    }
}

extension NativeExpenseSplit {
    /// Extra fields for a plan payment: only the budget part of the uncovered amount, nil when all stays on savings.
    func planPayload(uncovered: Int, day: String) -> Record? {
        let budget = max(0, uncovered - min(savings, uncovered))
        guard budget > 0 else { return nil }
        return ["budgetTreatment": .string("recovery"),
                "recoveryMonths": .string(chosenMonths(day: day).joined(separator: ", ")),
                "recoveryAmount": .number(Double(budget) / 100)]
    }
}
