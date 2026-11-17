import SwiftUI

// LifeOS design system (UI-FRAMEWORK-92, UI-LOOK-92).
// Reference: https://claude.ai/artifact/6CtaaD5n3hffmLWL1KSsXs
// Screens compose these components; colours, shapes and bar spacing live here
// and in NativeDesign. scripts/check-design-system.py keeps new screen code
// from drawing its own.

/// Section colours used only for a card's title, icon and its own bars, in the
/// style of Apple Health. Values are the production ones.
enum LOSection {
    case calendar, finance, nutrition, weight, neutral

    var color: Color {
        switch self {
        case .calendar: return NativeDesign.calendarTitle
        case .finance: return NativeDesign.financeTitle
        case .nutrition: return NativeDesign.nutritionTitle
        case .weight: return NativeDesign.healthWeight
        case .neutral: return .primary
        }
    }
}

/// Card header: coloured icon and title on the left, optional chevron on the right.
struct LOCardHeader: View {
    let title: String
    let systemImage: String
    var section: LOSection = .neutral
    var showsChevron = false

    var body: some View {
        HStack(spacing: NativeDesign.Space.small) {
            Label { Text(title) } icon: { LOSymbol(name: systemImage) }
                .font(.headline)
                .foregroundStyle(section.color)
            Spacer(minLength: NativeDesign.Space.small)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: NativeDesign.Layout.touchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Label for Liquid Glass buttons: neutral text, icon in the section colour.
struct LOActionLabel: View {
    let title: String
    let systemImage: String
    var section: LOSection = .neutral

    var body: some View {
        HStack(spacing: NativeDesign.Space.small) {
            LOSymbol(name: systemImage)
                .foregroundStyle(section == .neutral ? Color.primary : section.color)
                .accessibilityHidden(true)
            Text(title).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.body.weight(.semibold))
    }
}

/// The only button look of the app: Liquid Glass, capsule, neutral label.
/// `prominent` widens the button to fill its container (bottom actions).
struct LOGlassButtonStyle: ButtonStyle {
    var fillsWidth = false
    @Environment(\.nativeReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, NativeDesign.Space.large)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: fillsWidth ? NativeDesign.Layout.bottomAction : NativeDesign.Layout.touchTarget)
            .contentShape(Capsule())
            .modifier(NativeGlass())
            .opacity(isEnabled ? (configuration.isPressed ? NativeDesign.Motion.pressedOpacity : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? NativeDesign.Motion.pressedScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: configuration.isPressed)
    }
}

extension View {
    /// Pinned actions above the tab bar. On iOS 26 the system bar area keeps the
    /// scroll-edge effect and no background is drawn (no black band behind it).
    @ViewBuilder func loBottomActions<Actions: View>(@ViewBuilder _ actions: () -> Actions) -> some View {
        let bar = HStack(spacing: NativeDesign.Space.small) { actions() }
            .padding(.horizontal, NativeDesign.Layout.screenInset)
            .padding(.vertical, NativeDesign.Space.small)
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom, spacing: NativeDesign.Space.none) { bar }
        } else {
            self.safeAreaInset(edge: .bottom, spacing: NativeDesign.Space.none) { bar.background(.bar) }
        }
    }
}

/// One value of a statistics grid.
struct LOStat: Identifiable {
    let id: String
    let title: String
    let value: String
    let unit: String
    var accessibilityHint: String? = nil
}

/// Up to six values in one card, three per row, separated by hairlines.
/// With accessibility text sizes the grid becomes a single column.
struct LOStatGrid: View {
    let stats: [LOStat]
    var onSelect: ((LOStat) -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 3
        let rows = stride(from: 0, to: stats.count, by: columns).map { Array(stats[$0..<min($0 + columns, stats.count)]) }
        VStack(spacing: NativeDesign.Space.none) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().padding(.horizontal, NativeDesign.Space.medium) }
                HStack(alignment: .top, spacing: NativeDesign.Space.none) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, stat in
                        if column > 0 { Divider().padding(.vertical, NativeDesign.Space.medium) }
                        cell(stat)
                    }
                    if row.count < columns { ForEach(row.count..<columns, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) } }
                }
            }
        }
        .padding(.vertical, NativeDesign.Space.xs)
        .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
    }

    @ViewBuilder private func cell(_ stat: LOStat) -> some View {
        let content = VStack(alignment: .leading, spacing: NativeDesign.Space.xxs) {
            Text(stat.title).font(.footnote.weight(.medium)).foregroundStyle(NativeDesign.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: NativeDesign.Space.xs) {
                Text(stat.value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if !stat.unit.isEmpty { Text(stat.unit).font(.footnote).foregroundStyle(NativeDesign.secondary).lineLimit(1) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
        .padding(.horizontal, NativeDesign.Space.medium)
        .padding(.vertical, NativeDesign.Space.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.title + ", " + stat.value + (stat.unit.isEmpty ? "" : " " + stat.unit))
        // The caller's id is used as-is (e.g. "health-summary-tdee") so existing
        // identifiers survive the move to the grid.
        if let onSelect {
            Button { onSelect(stat) } label: { content }
                .buttonStyle(NativePressStyle())
                .accessibilityHint(stat.accessibilityHint ?? "Apre il dettaglio")
                .accessibilityIdentifier(stat.id)
        } else {
            content.accessibilityIdentifier(stat.id)
        }
    }
}

/// A row of up to four equal shortcuts (icon over label) in one card.
struct LOQuickItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct LOQuickRow: View {
    let items: [LOQuickItem]
    var section: LOSection = .neutral
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: NativeDesign.Space.none))
            : AnyLayout(HStackLayout(spacing: NativeDesign.Space.none))
        layout {
            ForEach(items) { item in
                Button(action: item.action) {
                    VStack(spacing: NativeDesign.Space.xs) {
                        Image(systemName: item.systemImage).font(.title3)
                            .foregroundStyle(section == .neutral ? Color.primary : section.color)
                            .accessibilityHidden(true)
                        Text(item.title).font(.caption.weight(.medium)).foregroundStyle(.primary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.quickRow)
                    .contentShape(Rectangle())
                }
                .buttonStyle(NativePressStyle())
                .accessibilityIdentifier(item.id)
            }
        }
        .padding(NativeDesign.Space.xs)
        .background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
    }
}

/// Glass pill that shows the active filter and opens a native menu.
struct LOFilterPill<Options: View>: View {
    let title: String
    let value: String
    let isActive: Bool
    let identifier: String
    @ViewBuilder let menu: () -> Options

    var body: some View {
        Menu(content: menu) {
            HStack(spacing: NativeDesign.Space.xs) {
                Text(isActive ? value : title + ": " + value).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, NativeDesign.Space.medium)
            .frame(minHeight: NativeDesign.Layout.touchTarget)
            .contentShape(Capsule())
            .modifier(NativeGlass())
        }
        .accessibilityLabel(title + ", " + value)
        .accessibilityIdentifier(identifier)
    }
}

/// SF Symbol or one of the app's own glyphs ("lifeos." prefix, drawn by NativeSymbol).
struct LOSymbol: View {
    let name: String
    var body: some View {
        if name.hasPrefix("lifeos.") { NativeSymbol(symbol: name) } else { Image(systemName: name) }
    }
}

/// Two or three exclusive choices in a glass capsule (native segmented look).
/// Each segment keeps its own accessibility identifier for UI tests.
struct LOSegmented: View {
    let options: [(title: String, id: String)]
    @Binding var selection: String
    var identifierPrefix = "segment-"

    var body: some View {
        HStack(spacing: NativeDesign.Space.none) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let selected = selection == option.title
                Button { selection = option.title } label: {
                    Text(option.title).font(.subheadline.weight(selected ? .semibold : .regular))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.segmentHeight)
                        .background { if selected { Capsule().fill(NativeDesign.surface).shadow(color: .black.opacity(0.12), radius: 2, y: 1) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(NativePressStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(option.title)
                .accessibilityIdentifier(identifierPrefix + option.id)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { selection = option.title }
            }
        }
        .padding(NativeDesign.Space.xxs)
        .modifier(NativeGlass(interactive: false))
    }
}

/// Glass container with rounded corners for floating control groups (map tools).
struct LOGlassPanel: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: NativeDesign.Layout.touchTarget / 2, style: .continuous)
        if #available(iOS 26.0, *) { content.glassEffect(.regular.interactive(), in: shape) }
        else { content.background(.regularMaterial, in: shape) }
    }
}
