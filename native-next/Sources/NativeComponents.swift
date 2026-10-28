import SwiftUI

private struct NativeForceReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Test-only forcing is additive: the system preference always wins.
    var nativeForceReduceMotion: Bool {
        get { self[NativeForceReduceMotionKey.self] }
        set { self[NativeForceReduceMotionKey.self] = newValue }
    }

    var nativeReduceMotion: Bool {
        #if DEBUG
        return accessibilityReduceMotion || nativeForceReduceMotion
        #else
        return accessibilityReduceMotion
        #endif
    }
}

struct NativeSurface: ViewModifier {
    var material = false
    @ViewBuilder
    func body(content: Content) -> some View {
        if material {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
        } else {
            content.background(NativeDesign.surface, in: RoundedRectangle(cornerRadius: NativeDesign.cardRadius, style: .continuous))
        }
    }
}
typealias NativePressStyle = PlainButtonStyle

enum NativeCardDensity: Equatable {
    case standard, compact
    var inset: CGFloat { self == .standard ? NativeDesign.Layout.cardInset : NativeDesign.Layout.compactCardInset }
    var gap: CGFloat { self == .standard ? NativeDesign.Space.large : NativeDesign.Space.medium }
}
struct NativeCard<Content: View>: View {
    let content: Content
    var material: Bool
    var density: NativeCardDensity
    init(material: Bool = false, density: NativeCardDensity = .standard, @ViewBuilder content: () -> Content) {
        self.material = material; self.density = density; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: density.gap) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(density.inset)
            .modifier(NativeSurface(material: material))
    }
}
struct NativeGroupedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: NativeDesign.Space.none) { content }
            .padding(.horizontal, NativeDesign.Layout.groupedInset).padding(.vertical, NativeDesign.Space.xs)
            .modifier(NativeSurface())
    }
}
struct NativeRoutineAppearance: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass).buttonBorderShape(.roundedRectangle(radius: NativeDesign.controlRadius))
        } else {
            content.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: NativeDesign.controlRadius))
        }
    }
}
struct NativeIcon: View {
    let name: String
    var color: Color = NativeDesign.accent
    var body: some View {
        Image(systemName: name).symbolVariant(.none).symbolRenderingMode(.monochrome).font(NativeDesign.symbol)
            .foregroundStyle(color).frame(width: NativeDesign.Layout.iconTile, height: NativeDesign.Layout.iconTile)
            .background(NativeDesign.inset, in: RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
struct NativeListAppearance: ViewModifier {
    func body(content: Content) -> some View {
        content.listStyle(.insetGrouped).listSectionSpacing(NativeDesign.gap)
            .font(NativeDesign.body).environment(\.defaultMinListRowHeight, NativeDesign.Layout.rowHeight)
            .contentMargins(.horizontal, NativeDesign.Layout.screenInset, for: .scrollContent)
            .listRowSpacing(0).contentMargins(.top, NativeDesign.Space.small, for: .scrollContent).contentMargins(.bottom, NativeDesign.Layout.scrollClearance, for: .scrollContent).scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden).background(NativeDesign.canvas)
    }
}
struct NativeGlass: ViewModifier {
    var interactive = true
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if interactive { content.glassEffect(.regular.interactive(), in: Capsule()) }
            else { content.glassEffect(.regular, in: Capsule()) }
        } else { content.background(.regularMaterial, in: Capsule()) }
    }
}
struct NativeConnectionBadge: View {
    @EnvironmentObject var store: NativeStore
    private var text: String {
        if store.isDemo { return "Demo" }
        if store.busy { return "Salvataggio" }
        if store.syncing { return "Sincronizzazione" }
        if !store.state.pending.isEmpty { return "\(store.state.pending.count) in coda" }
        if !store.syncStatus.isEmpty && store.syncStatus != "Aggiornato" { return "Da aggiornare" }
        return store.sharedDatabase ? "Condiviso con il sito" : store.server == nil ? "Sul dispositivo" : "Collegato"
    }
    var body: some View {
        NativeStatusBadge(title: text, tone: store.isDemo || !store.state.pending.isEmpty || (!store.syncStatus.isEmpty && store.syncStatus != "Aggiornato") ? .warning : .success, showsIndicator: true, loading: store.busy || store.syncing)
    }
}

struct NativeCheckmark: View {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let checked: Bool
    var body: some View {
        Image(systemName: checked ? "largecircle.fill.circle" : "circle")
            .symbolRenderingMode(.monochrome).font(.title2.weight(.regular))
            .foregroundStyle(checked ? NativeDesign.accent : NativeDesign.secondary)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .animation(reduceMotion ? nil : .default, value: checked)
            .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
            .contentShape(Rectangle()).accessibilityHidden(true)
    }
}
struct NativeCompletionButton: View {
    @State private var touchFeedback = 0
    let checked: Bool
    let label: String
    let action: () -> Void
    var body: some View {
        Button { touchFeedback &+= 1; action() } label: { NativeCheckmark(checked: checked) }
            .buttonStyle(.borderless)
            .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
            .accessibilityLabel(label)
            .sensoryFeedback(.selection, trigger: touchFeedback)
            .accessibilityValue(checked ? "Completata" : "Da completare")
    }
}
struct NativeDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            .foregroundStyle(NativeDesign.secondary).accessibilityHidden(true)
    }
}
struct NativeRowText: View {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let title: String
    var subtitle: String = ""
    var completed = false
    var titleLineLimit: Int?
    var titleIdentifier: String?
    var body: some View {
        VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
            titleView.lineLimit(titleLineLimit)
                .foregroundStyle(completed ? NativeDesign.secondary : Color.primary).fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty {
                Text(subtitle).font(NativeDesign.metadata).foregroundStyle(NativeDesign.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
            .multilineTextAlignment(.leading)
            .animation(reduceMotion ? nil : .easeOut(duration: NativeDesign.Motion.selectionDuration), value: completed)
    }
    @ViewBuilder private var titleView: some View {
        if let titleIdentifier { Text(title).font(NativeDesign.body).accessibilityIdentifier(titleIdentifier) }
        else { Text(title).font(NativeDesign.body) }
    }
}
struct NativeIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(NativeDesign.symbol).symbolRenderingMode(.monochrome).foregroundStyle(NativeDesign.accent)
                .frame(width: NativeDesign.Layout.touchTarget, height: NativeDesign.Layout.touchTarget)
                .contentShape(Rectangle())
        }.buttonStyle(NativePressStyle()).accessibilityLabel(label)
    }
}
struct NativeSectionHeader<Accessory: View>: View {
    let title: String
    var titleIdentifier: String?
    let accessory: Accessory
    init(_ title: String, titleIdentifier: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title; self.titleIdentifier = titleIdentifier; self.accessory = accessory()
    }
    var body: some View {
        HStack(spacing: NativeDesign.Space.medium) {
            if let titleIdentifier { Text(title).font(NativeDesign.heading).accessibilityIdentifier(titleIdentifier) }
            else { Text(title).font(NativeDesign.heading) }
            Spacer(minLength: NativeDesign.Space.small)
            accessory
        }
    }
}
enum NativeTone {
    case neutral, success, warning, danger
    var color: Color {
        switch self {
        case .neutral: return NativeDesign.secondary
        case .success: return NativeDesign.success
        case .warning: return NativeDesign.warning
        case .danger: return NativeDesign.danger
        }
    }
}
struct NativeStatusBadge: View {
    let title: String
    var symbol: String?
    var tone: NativeTone = .neutral
    var showsIndicator = false
    var loading = false
    var body: some View {
        HStack(spacing: NativeDesign.Space.xs) {
            if loading { ProgressView().controlSize(.mini) }
            else if let symbol { Image(systemName: symbol) }
            else if showsIndicator { Circle().fill(tone.color).frame(width: NativeDesign.Layout.statusDot, height: NativeDesign.Layout.statusDot) }
            Text(title)
        }.font(NativeDesign.metadata).foregroundStyle(tone.color)
            .padding(.horizontal, NativeDesign.Space.small).padding(.vertical, NativeDesign.Space.xs)
            .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: NativeDesign.badgeRadius, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
struct NativeSelectionSurface: ViewModifier {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let selected: Bool
    var tint: Color = NativeDesign.accent
    var outlined = false
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous)
                .fill(selected ? tint.opacity(0.18) : NativeDesign.inset)
                .animation(reduceMotion ? nil : .default, value: selected)
        }.overlay {
            RoundedRectangle(cornerRadius: NativeDesign.controlRadius, style: .continuous)
                .stroke(selected && outlined ? tint : .clear, lineWidth: 1.5)
                .animation(reduceMotion ? nil : .default, value: selected)
        }
    }
}
struct NativeCategoryChip: View {
    @State private var touchFeedback = 0
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button { if !selected { touchFeedback &+= 1 }; action() } label: {
            Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, NativeDesign.Space.medium)
                .frame(minWidth: NativeDesign.Layout.categoryWidth, minHeight: NativeDesign.Layout.touchTarget)
                .modifier(NativeSelectionSurface(selected: selected))
        }.buttonStyle(NativePressStyle()).accessibilityAddTraits(selected ? .isSelected : [])
            .sensoryFeedback(.selection, trigger: touchFeedback)
    }
}
/// Contextual Apple-style chips: visible surface and a full 44 pt touch target.
struct NativeInlineAction: View {
    let symbol: String
    var title = ""
    let label: String
    var destructive = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: NativeDesign.Space.small) {
                Image(systemName: symbol).font(.body.weight(.medium))
                if !title.isEmpty { Text(title).font(.subheadline.weight(.medium)).fixedSize() }
            }
            .foregroundStyle(destructive ? NativeDesign.danger : NativeDesign.accent)
            .padding(.horizontal, NativeDesign.Space.medium)
            .frame(minWidth: NativeDesign.Layout.touchTarget, minHeight: NativeDesign.Layout.touchTarget)
            .background(NativeDesign.actionSurface, in: Capsule())
            .contentShape(Capsule())
        }.buttonStyle(NativePressStyle()).accessibilityLabel(label)
    }
}

struct NativeInlineMessage: View {
    let text: String
    var tone: NativeTone = .danger
    var body: some View {
        Text(text).font(NativeDesign.metadata).foregroundStyle(tone.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// One checklist row for Home, task lists and calendar occurrences.
// Actions remain separate: completing never opens the editor.
struct NativeChecklistRow: View {
    let title: String
    var subtitle = ""
    var checked = false
    var dueDay = ""
    var showsDisclosure = true
    var titleIdentifier: String?
    var completionIdentifier = ""
    var openIdentifier = ""
    let completionLabel: String
    let onComplete: () -> Void
    let onOpen: () -> Void
    var body: some View {
        HStack(spacing: NativeDesign.Space.small) {
            NativeCompletionButton(checked: checked, label: completionLabel, action: onComplete)
                .accessibilityIdentifier(completionIdentifier)
            Button(action: onOpen) {
                HStack(spacing: NativeDesign.Space.small) {
                    VStack(alignment: .leading, spacing: NativeDesign.Space.xs) {
                        NativeRowText(title: title, subtitle: subtitle, completed: checked, titleIdentifier: titleIdentifier)
                        if !dueDay.isEmpty { NativeDueBadge(day: dueDay) }
                    }
                    if showsDisclosure { NativeDisclosureIndicator() }
                }.frame(maxWidth: .infinity, minHeight: NativeDesign.Layout.touchTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.borderless).accessibilityIdentifier(openIdentifier).accessibilityLabel(title)
        }
    }
}

// List retains native swipe/reorder; its row geometry matches NativeGroupedCard.
struct NativeChecklistListAppearance: ViewModifier {
    func body(content: Content) -> some View {
        content.listStyle(.plain).listSectionSpacing(NativeDesign.Space.section)
            .font(NativeDesign.body).environment(\.defaultMinListRowHeight, NativeDesign.Layout.rowHeight)
            .contentMargins(.horizontal, NativeDesign.Layout.screenInset, for: .scrollContent)
            .contentMargins(.top, NativeDesign.Space.small, for: .scrollContent)
            .contentMargins(.bottom, NativeDesign.Layout.scrollClearance, for: .scrollContent)
            .scrollContentBackground(.hidden).background(NativeDesign.canvas)
            .scrollBounceBehavior(.basedOnSize)
    }
}
struct NativeChecklistListRow: ViewModifier {
    let first: Bool
    let last: Bool
    func body(content: Content) -> some View {
        content.listRowInsets(EdgeInsets(
            top: NativeDesign.Space.xs + (first ? NativeDesign.Space.xs : 0),
            leading: NativeDesign.Layout.groupedInset,
            bottom: NativeDesign.Space.xs + (last ? NativeDesign.Space.xs : 0),
            trailing: NativeDesign.Layout.groupedInset))
            .listRowSeparator(.hidden).listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
            .overlay(alignment: .bottom) {
                if !last {
                    Divider().padding(.leading, NativeDesign.Layout.touchTarget + NativeDesign.Space.small)
                }
            }
    }
}

/// Animate only a number's glyphs, never the surrounding row, list or navigation.
struct NativeNumericFeedback: ViewModifier {
    @Environment(\.nativeReduceMotion) private var reduceMotion
    let value: Double
    var enabled = true
    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion || !enabled ? .identity : .numericText())
            .animation(reduceMotion || !enabled ? nil : .default, value: value)
            .transaction { transaction in
                if reduceMotion || !enabled { transaction.animation = nil; transaction.disablesAnimations = true }
            }
    }
}
