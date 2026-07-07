import SwiftUI

enum OverlayTab: String, CaseIterable {
    case comps = "Comps"
    case augments = "Augments"
    case items = "Items"
    case odds = "Odds"
}

struct OverlayRootView: View {
    @StateObject private var store = MetaStore.shared
    @State private var tab: OverlayTab = .augments
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Rectangle().fill(Theme.divider).frame(height: 1)
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).fill(Theme.paper.opacity(0.72)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.divider))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(minWidth: 300, minHeight: 460)
        .preferredColorScheme(.dark)
    }

    @ObservedObject private var lcu = LCUClient.shared

    private var statusColor: Color {
        if lcu.phase == "Disconnected" { return Theme.secondary.opacity(0.4) }
        if lcu.isTFTGame && (lcu.phase == "InProgress" || lcu.phase == "GameStart") {
            return Color(red: 0.36, green: 0.80, blue: 0.44)
        }
        return Theme.tierColor("B")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("⚔️").font(.system(size: 13))
            Text("TFT Overlay")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .help("League: \(lcu.phase)")
            Spacer()
            Text("⌥Space")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondary)
            Button {
                OverlayPanelController.shared.toggle()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(OverlayTab.allCases, id: \.self) { t in
                Button {
                    tab = t
                    search = ""
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 12, weight: tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? Theme.ink : Theme.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(tab == t ? Theme.fill : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .comps: CompsView(comps: store.comps, search: $search)
        case .augments: AugmentsView(augments: store.augments, tierOrder: store.tierOrder, search: $search)
        case .items: ItemsView(items: store.items, search: $search)
        case .odds: OddsView(odds: store.odds, pool: store.pool, champions: store.champions)
        }
    }
}

// MARK: - Augment pick banner

/// Shown when the OCR spotter sees the augment choice screen:
/// the offered augments, best tier first.
struct AugmentPickBanner: View {
    let offered: [Augment]
    let onDismiss: () -> Void

    private var sorted: [Augment] {
        let order = ["S": 0, "A": 1, "B": 2, "C": 3, "D": 4]
        return offered.sorted { (order[$0.tier] ?? 9) < (order[$1.tier] ?? 9) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⚡️ AUGMENT PICK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.tierColor("A"))
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(sorted) { augment in
                HStack(spacing: 8) {
                    Text(augment.tier)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.black)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.tierColor(augment.tier)))
                    IconImage(url: augment.icon, size: 22)
                    Text(augment.name)
                        .font(.system(size: 13, weight: augment.id == sorted.first?.id ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.fill)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.tierColor("A").opacity(0.35)))
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

// MARK: - Shared bits

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.fill))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Floating name label on hover — same treatment as UnitIcon's champ label.
struct HoverLabel: ViewModifier {
    let text: String
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering = $0 }
            .overlay(alignment: .top) {
                if hovering {
                    Text(text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(red: 0.16, green: 0.16, blue: 0.16))
                                .shadow(color: .black.opacity(0.5), radius: 3)
                        )
                        .fixedSize()
                        .offset(y: -24)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(hovering ? 10 : 0)
    }
}

extension View {
    /// Attach a hover name label; no-op when the name is unknown.
    @ViewBuilder
    func hoverLabel(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            modifier(HoverLabel(text: text))
        } else {
            self
        }
    }
}

/// Hover "?" that explains a stat in a floating bubble. Custom-built:
/// system .help tooltips don't fire inside a non-activating overlay panel.
/// The bubble grows upward so it always draws over already-rendered rows.
struct InfoTip: View {
    let text: String
    /// Shift the bubble left when the icon sits mid-row, so it stays inside the panel.
    var xOffset: CGFloat = 0
    /// Open downward instead (for tips near the top of a scroll view, where
    /// an upward bubble would clip). The row hosting a downward tip needs a
    /// raised zIndex so the bubble draws over the rows beneath it.
    var below = false
    @State private var hovering = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.secondary.opacity(hovering ? 1 : 0.7))
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering = $0 }
            .overlay(alignment: below ? .topLeading : .bottomLeading) {
                if hovering {
                    Text(text)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .frame(width: 220, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.16, green: 0.16, blue: 0.16))
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        )
                        .offset(x: xOffset, y: below ? 16 : -16)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(hovering ? 50 : 0)
    }
}

/// Icons ship inside the app bundle (Resources/Icons) — loaded from disk once,
/// cached in memory, never fetched from the network at render time.
enum BundledIcons {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(named name: String) -> NSImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        let base = (name as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: "png", subdirectory: "Icons"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

struct IconImage: View {
    let url: String?
    var size: CGFloat = 22

    var body: some View {
        Group {
            if let name = url, let image = BundledIcons.image(named: name) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(Theme.fill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Augments

struct AugmentsView: View {
    let augments: [Augment]
    let tierOrder: [String]
    @Binding var search: String
    @State private var expanded: Set<String> = []
    @State private var rarity: AugmentRarity = .all

    private var filtered: [Augment] {
        var result = augments
        if rarity != .all {
            result = result.filter { $0.rarity == rarity.rawValue }
        }
        if !search.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        return result
    }

    private func rarityColor(_ r: AugmentRarity) -> Color {
        switch r {
        case .all: return Theme.ink
        case .silver: return Color(red: 0.75, green: 0.78, blue: 0.80)
        case .gold: return Color(red: 1.00, green: 0.76, blue: 0.34)
        case .prismatic: return Color(red: 0.62, green: 0.79, blue: 1.00)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $search)
            HStack(spacing: 4) {
                ForEach(AugmentRarity.allCases, id: \.self) { r in
                    Button {
                        rarity = r
                    } label: {
                        Text(r.label)
                            .font(.system(size: 11, weight: rarity == r ? .semibold : .regular))
                            .foregroundStyle(rarity == r ? Theme.paper : rarityColor(r).opacity(0.85))
                            .fixedSize()
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(rarity == r ? rarityColor(r) : Theme.fill))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(tierOrder, id: \.self) { tier in
                        let group = filtered.filter { $0.tier == tier }
                        if !group.isEmpty {
                            tierHeader(tier, count: group.count)
                            ForEach(group) { augment in
                                row(augment)
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func tierHeader(_ tier: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(tier)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.tierColor(tier)))
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func row(_ augment: Augment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                IconImage(url: augment.icon, size: 20)
                Text(augment.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: expanded.contains(augment.id) ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.secondary)
            }
            if expanded.contains(augment.id), !augment.desc.isEmpty {
                Text(augment.desc)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(2)
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            if expanded.contains(augment.id) {
                expanded.remove(augment.id)
            } else {
                expanded.insert(augment.id)
            }
        }
    }
}

// MARK: - Comps

struct CompsView: View {
    let comps: [Comp]
    @Binding var search: String
    @State private var sort: CompSort = .best

    enum CompSort: String, CaseIterable {
        case best = "Best"
        case popular = "Popular"
    }

    enum StyleFilter: String, CaseIterable {
        case all = "All"
        case reroll = "Reroll"
        case fast9 = "Fast 9"
        case standard = "Standard"

        var styleValue: String? {
            switch self {
            case .all: return nil
            case .reroll: return "reroll"
            case .fast9: return "fast9"
            case .standard: return "standard"
            }
        }
    }

    @State private var styleFilter: StyleFilter = .all
    @State private var expanded: Set<Int> = []

    private var filtered: [Comp] {
        var result = comps
        if let style = styleFilter.styleValue {
            result = result.filter { ($0.style ?? "standard") == style }
        }
        if !search.isEmpty {
            result = result.filter { $0.matches(search) }
        }
        if sort == .popular {
            result = result.sorted { ($0.games ?? 0) > ($1.games ?? 0) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $search)
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(CompSort.allCases, id: \.self) { s in
                        Button {
                            sort = s
                        } label: {
                            Text(s.rawValue)
                                .font(.system(size: 11, weight: sort == s ? .semibold : .regular))
                                .foregroundStyle(sort == s ? Theme.paper : Theme.secondary)
                                .fixedSize()
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(sort == s ? Theme.ink : Theme.fill))
                        }
                        .buttonStyle(.plain)
                    }
                    Rectangle().fill(Theme.divider).frame(width: 1, height: 14).padding(.horizontal, 3)
                    ForEach(StyleFilter.allCases, id: \.self) { f in
                        Button {
                            styleFilter = f
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 11, weight: styleFilter == f ? .semibold : .regular))
                                .foregroundStyle(styleFilter == f ? Theme.paper : Theme.secondary)
                                .fixedSize()
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(styleFilter == f ? Theme.ink : Theme.fill))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 8)
            compList
        }
    }

    private var compList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(filtered) { comp in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(comp.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if let badge = comp.styleBadge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(comp.style == "reroll"
                                        ? Theme.tierColor("A")
                                        : Color(red: 0.62, green: 0.79, blue: 1.00))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.fill))
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            Spacer()
                            if let avg = comp.avgPlace {
                                Text(String(format: "%.2f avg", avg))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(avg <= 4.2 ? Theme.tierColor("A") : Theme.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                        }
                        HStack(spacing: 4) {
                            // Scroll the unit icons when the panel is narrow.
                            // Clipping is disabled vertically so the hover
                            // champ-name labels aren't cut off, but kept at the
                            // horizontal edges so scrolled-out icons vanish cleanly.
                            ScrollView(.horizontal) {
                                unitIcons(comp)
                                    .contentShape(Rectangle())
                                    .onTapGesture { toggleExpanded(comp.id) }
                            }
                            .scrollIndicators(.hidden)
                            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
                            .scrollClipDisabled()
                            .clipShape(HorizontalOnlyClip())
                            Spacer(minLength: 8)
                            if let games = comp.games {
                                Text("\(games.formatted()) games")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                        }
                        if expanded.contains(comp.id) {
                            bisRows(for: comp)
                            augmentRecs(for: comp)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded(comp.id) }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func unitIcons(_ comp: Comp) -> some View {
        HStack(spacing: 4) {
            ForEach(comp.units, id: \.self) { unit in
                UnitIcon(unit: unit)
            }
        }
    }

    private func toggleExpanded(_ id: Int) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    /// Expanded detail: BiS build per itemized unit, carries first.
    private func bisRows(for comp: Comp) -> some View {
        let itemized = comp.units
            .filter { !($0.items ?? []).isEmpty }
            .sorted { ($0.star3 ?? false) && !($1.star3 ?? false) }
        return VStack(alignment: .leading, spacing: 5) {
            ForEach(itemized, id: \.self) { unit in
                HStack(spacing: 6) {
                    UnitIcon(unit: unit, size: 24)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7))
                        .foregroundStyle(Theme.secondary)
                    ForEach(unit.items ?? [], id: \.self) { item in
                        IconImage(url: item, size: 20)
                            .hoverLabel(MetaStore.shared.itemNamesByIcon[item])
                    }
                    Spacer()
                }
            }
        }
        .padding(.top, 6)
        .padding(.leading, 2)
    }

    /// Expanded detail: curated augment picks for this comp, tier-tagged.
    @ViewBuilder
    private func augmentRecs(for comp: Comp) -> some View {
        if let recs = comp.augments, !recs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("AUGMENTS")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
                        ForEach(uniqueAugments(recs), id: \.self) { rec in
                            AugmentChip(rec: rec)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, 6)
        }
    }

    /// MetaTFT lists silver/gold/prismatic variants of the same augment
    /// separately ("Heroic Grab Bag", "+", "++", or "… I/II/III") with one
    /// shared icon — collapse them to a single chip.
    private func uniqueAugments(_ recs: [CompAugmentRec]) -> [CompAugmentRec] {
        var seen = Set<String>()
        return recs.filter { rec in
            let base = rec.name.replacingOccurrences(
                of: #"(\+{1,2}|\s+I{1,3})$"#, with: "", options: .regularExpression
            )
            return seen.insert(base).inserted
        }
    }
}

/// Clip tight at the left/right edges but leave vertical headroom, so a
/// horizontal scroller cuts off scrolled-out content without decapitating
/// hover labels that float above it.
struct HorizontalOnlyClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - 60, width: rect.width, height: rect.height + 120))
    }
}

/// Augment chip that expands inline on hover to reveal the augment name.
/// (Chips sit inside a horizontal ScrollView, which would clip a floating
/// bubble — growing the chip itself dodges the clipping entirely.)
struct AugmentChip: View {
    let rec: CompAugmentRec
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 3) {
            IconImage(url: rec.icon, size: 18)
            if hovering {
                Text(rec.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            Text(rec.tier)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.tierColor(rec.tier))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.fill))
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.12)) { hovering = hover }
        }
    }
}

/// Unit icon with three gold stars underneath when the comp
/// usually three-stars it; hover shows the champ name.
/// (Custom hover label — system .help tooltips don't fire reliably
/// inside a non-activating overlay panel.)
struct UnitIcon: View {
    let unit: CompUnit
    var size: CGFloat = 28
    @State private var hovering = false

    private static let starGold = Color(red: 1.00, green: 0.76, blue: 0.34)

    var body: some View {
        VStack(spacing: 1) {
            IconImage(url: unit.icon, size: size)
            HStack(spacing: 0.5) {
                if unit.star3 == true {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: size * 0.24))
                            .foregroundStyle(Self.starGold)
                    }
                }
            }
            .frame(height: size * 0.28) // reserve space so icons stay aligned
        }
        .onHover { hovering = $0 }
        .overlay(alignment: .top) {
            if hovering {
                Text(unit.star3 == true ? "\(unit.name) 3★" : unit.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.16))
                            .shadow(color: .black.opacity(0.5), radius: 3)
                    )
                    .fixedSize()
                    .offset(y: -(size * 0.85))
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .zIndex(hovering ? 10 : 0)
    }
}

// MARK: - Items

struct ItemsView: View {
    let items: [ItemStat]
    @Binding var search: String
    @State private var category: ItemCategory = .completed

    private var filtered: [ItemStat] {
        var result = items
        if category != .all {
            result = result.filter { $0.category == category.rawValue }
        }
        if !search.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $search)
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(ItemCategory.allCases, id: \.self) { c in
                        Button {
                            category = c
                        } label: {
                            Text(c.label)
                                .font(.system(size: 11, weight: category == c ? .semibold : .regular))
                                .foregroundStyle(category == c ? Theme.paper : Theme.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(category == c ? Theme.ink : Theme.fill))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 8)
            HStack {
                Text("ITEM").font(.system(size: 9, weight: .semibold)).tracking(0.5)
                Spacer()
                Text("AVG").font(.system(size: 9, weight: .semibold)).frame(width: 40, alignment: .trailing)
                Text("TOP4").font(.system(size: 9, weight: .semibold)).frame(width: 44, alignment: .trailing)
            }
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        HStack(spacing: 8) {
                            IconImage(url: item.icon, size: 20)
                            Text(item.name)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .help(item.desc)
                            Spacer()
                            Text(String(format: "%.2f", item.avgPlace))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(item.avgPlace <= 4.2 ? Theme.tierColor("A") : Theme.secondary)
                                .frame(width: 40, alignment: .trailing)
                            Text(String(format: "%.0f%%", item.top4 * 100))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Shop odds

struct OddsView: View {
    let odds: [ShopOdds]
    let pool: PoolInfo?
    let champions: [Champion]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                oddsTable
                if let pool {
                    bagRow(pool)
                    HitCalculator(odds: odds, pool: pool, champions: champions)
                }
            }
            .padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }

    /// Copies of each unit in the shared pool, per cost tier.
    private func bagRow(_ pool: PoolInfo) -> some View {
        HStack {
            HStack(spacing: 3) {
                Text("BAG")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize()
                InfoTip(text: "How many copies of each individual champ exist in the shared pool, by cost. Example: every 3-cost has \(pool.bagSizes[2]) copies split across all 8 players.")
            }
            .frame(width: 44, alignment: .leading)
            ForEach(0..<5, id: \.self) { i in
                Text("\(pool.bagSizes[i])")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.costColors[i])
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
        }
    }

    private var oddsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 3) {
                    Text("LVL")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize()
                    InfoTip(
                        text: "Chance that each of the 5 shop slots rolls a champ of that cost, at your level. Level up to unlock higher costs.",
                        below: true
                    )
                }
                .frame(width: 44, alignment: .leading)
                ForEach(0..<5, id: \.self) { cost in
                    Text("\(cost + 1)🪙")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.costColors[cost])
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .zIndex(1) // keep the LVL tip's downward bubble above the odds rows
            ForEach(odds) { row in
                HStack {
                    Text("\(row.level)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, alignment: .leading)
                    ForEach(0..<5, id: \.self) { cost in
                        let value = cost < row.odds.count ? row.odds[cost] : 0
                        Text(value > 0 ? String(format: "%.0f%%", value * 100) : "–")
                            .font(.system(size: 12))
                            .foregroundStyle(value > 0 ? Theme.ink : Theme.secondary.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(row.level % 2 == 0 ? Theme.fill.opacity(0.5) : .clear)
            }
        }
    }
}

/// "Will I hit my unit if I roll down, and how much gold does it take?"
/// Pool math: per-slot chance = (shop odds for that cost at your level)
///            × (copies of the unit left ÷ total same-cost pool left).
/// Your copies count toward the 3/9 you need AND deplete the pool;
/// opponents' copies only deplete the pool. Gold-needed answers use the
/// binomial distribution over 5 slots per 2-gold shop.
struct HitCalculator: View {
    let odds: [ShopOdds]
    let pool: PoolInfo
    let champions: [Champion]

    @State private var query = ""
    @State private var selected: Champion?
    @State private var fallbackCost = 3
    @State private var level = 7
    @State private var mine = 3
    @State private var opponents = 0
    @State private var otherSameCostGone = 15
    @State private var wantThreeStar = true

    // MARK: - Pool math

    private var cost: Int { selected?.cost ?? fallbackCost }
    private var bag: Int { pool.bagSizes[cost - 1] }
    private var remaining: Int { max(bag - mine - opponents, 0) }
    private var targetCopies: Int { wantThreeStar ? 9 : 3 }
    private var need: Int { max(targetCopies - mine, 0) }

    private var slotOdds: Double {
        guard let row = odds.first(where: { $0.level == level }),
              cost - 1 < row.odds.count else { return 0 }
        return row.odds[cost - 1]
    }

    /// Per-slot chance, using pool state averaged over the copies still needed
    /// (each copy you buy shrinks both your unit's remaining count and the pool).
    private var perSlot: Double {
        let depletion = Double(max(need - 1, 0)) / 2
        let remainingAvg = Double(remaining) - depletion
        let poolLeft = Double(pool.champCounts[cost - 1] * bag - mine - opponents - otherSameCostGone) - depletion
        guard remainingAvg > 0, poolLeft > 0 else { return 0 }
        return slotOdds * remainingAvg / poolLeft
    }

    private var perShop: Double { 1 - pow(1 - perSlot, 5) }

    /// P(at least `need` successes) in `slots` binomial trials.
    private func probHit(slots: Int, p: Double) -> Double {
        guard need > 0 else { return 1 }
        guard p > 1e-9, slots >= need else { return 0 }
        let clamped = min(p, 1 - 1e-9)
        var cdf = 0.0
        var logChoose = 0.0
        for i in 0..<need {
            if i > 0 { logChoose += log(Double(slots - i + 1)) - log(Double(i)) }
            cdf += exp(logChoose + Double(i) * log(clamped) + Double(slots - i) * log(1 - clamped))
        }
        return max(0, min(1, 1 - cdf))
    }

    /// Smallest gold spend whose hit probability reaches the threshold.
    private func goldNeeded(for threshold: Double) -> String {
        guard need > 0 else { return "0" }
        guard perSlot > 0 else { return "—" }
        var gold = 2
        while gold <= 300 {
            if probHit(slots: gold / 2 * 5, p: perSlot) >= threshold {
                return "\(gold)"
            }
            gold += 2
        }
        return "300+"
    }

    /// Expected gold, buying copy by copy as the pool depletes.
    private var expectedGold: String {
        guard need > 0 else { return "0" }
        let poolNow = Double(pool.champCounts[cost - 1] * bag - mine - opponents - otherSameCostGone)
        var shops = 0.0
        for i in 0..<need {
            let rem = Double(remaining - i)
            let left = poolNow - Double(i)
            guard rem > 0, left > 0, slotOdds > 0 else { return "—" }
            let p = slotOdds * rem / left
            shops += 1 / (1 - pow(1 - p, 5))
        }
        return "~\(Int((shops * 2).rounded()))"
    }

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("HIT CALCULATOR")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondary)
                InfoTip(
                    text: "Your odds of finding a unit when you roll. Everyone draws from one shared pool — tell it how many copies are already gone and it works out the chance per shop and the gold a rolldown will cost. One shop = 5 slots for 2 gold.",
                    xOffset: -100
                )
            }
            .padding(.top, 16)

            champPicker

            HStack(spacing: 4) {
                Text("Target")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                InfoTip(
                    text: "3★ needs 9 total copies, 2★ needs 3. Copies already on your board count toward the total.",
                    xOffset: -40
                )
                Spacer()
                ForEach([false, true], id: \.self) { three in
                    Button {
                        wantThreeStar = three
                    } label: {
                        Text(three ? "3★" : "2★")
                            .font(.system(size: 11, weight: wantThreeStar == three ? .semibold : .regular))
                            .foregroundStyle(wantThreeStar == three ? .black : Theme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(
                                wantThreeStar == three
                                    ? Color(red: 1.00, green: 0.76, blue: 0.34)
                                    : Theme.fill
                            ))
                    }
                    .buttonStyle(.plain)
                }
            }

            if selected == nil {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { c in
                        Button {
                            fallbackCost = c
                        } label: {
                            Text("\(c)🪙")
                                .font(.system(size: 11, weight: fallbackCost == c ? .semibold : .regular))
                                .foregroundStyle(fallbackCost == c ? .black : Theme.costColors[c - 1])
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(fallbackCost == c ? Theme.costColors[c - 1] : Theme.fill))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Text("bag of \(bag)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                }
            }

            counterRow("Your level", value: $level, range: 3...11)
            counterRow("Copies on your board", value: $mine, range: 0...9)
            counterRow(
                "Copies opponents hold", value: $opponents, range: 0...max(bag - mine, 0),
                tip: "Copies other players bought. They don't count toward your target, but they're gone from the shared pool — fewer left for you to find.",
                tipOffset: -135
            )
            counterRow(
                "Other \(cost)-costs out of pool", value: $otherSameCostGone, range: 0...90, step: 3,
                tip: "All \(cost)-costs share one pool, so every other \(cost)-cost the lobby holds dilutes your hit rate. Rough guide: ~2–3 per opponent mid-game.",
                tipOffset: -150
            )

            results
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var champPicker: some View {
        if let champ = selected {
            HStack(spacing: 8) {
                IconImage(url: champ.icon, size: 26)
                Text(champ.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(champ.cost)-cost · bag of \(bag)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.costColors[champ.cost - 1])
                Spacer()
                Button {
                    selected = nil
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.fill))
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondary)
                    TextField("Search champion…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.fill))

                if !query.isEmpty {
                    ForEach(champions.filter {
                        $0.name.localizedCaseInsensitiveContains(query)
                    }.prefix(4)) { champ in
                        Button {
                            selected = champ
                            mine = min(mine, 9)
                        } label: {
                            HStack(spacing: 8) {
                                IconImage(url: champ.icon, size: 20)
                                Text(champ.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.ink)
                                Text("\(champ.cost)-cost")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.costColors[champ.cost - 1])
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        VStack(alignment: .leading, spacing: 6) {
            plainRow(
                "Copies left in pool", "\(remaining) of \(bag)",
                tip: "The bag holds \(bag) copies of every \(cost)-cost champ, shared by all 8 players. What's left is the bag minus yours and your opponents' copies.",
                tipOffset: -110
            )
            plainRow("Still need", need == 0 ? "done ✓" : "\(need) more for \(wantThreeStar ? "3★" : "2★")")
            if need > remaining {
                Text("Not enough copies left — \(wantThreeStar ? "3★" : "2★") is impossible from this pool.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.tierColor("S"))
            } else if need > 0 {
                probRow(
                    "Per shop (≥1 copy)", perShop,
                    tip: "Chance at least one copy of your champ shows up in a single shop of 5 slots.",
                    tipOffset: -115
                )
                HStack(spacing: 4) {
                    Text("Gold for 50 / 80 / 95%")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                    InfoTip(
                        text: "Gold to spend rolling (2 per refresh) to have a 50%, 80%, or 95% chance of finding every copy you still need. Treat the 95% number as your safe rolldown budget.",
                        xOffset: -135
                    )
                    Spacer()
                    Text("\(goldNeeded(for: 0.5)) / \(goldNeeded(for: 0.8)) / \(goldNeeded(for: 0.95))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                plainRow(
                    "Average gold to hit", expectedGold,
                    tip: "Expected rolling cost. Half your rolldowns will cost less than this, half more — budget with the 95% number if missing loses you the game.",
                    tipOffset: -115
                )
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.fill))
    }

    /// −/+ controls that behave inside a non-activating panel
    /// (native Stepper is unreliable there).
    private func counterRow(
        _ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1,
        tip: String? = nil, tipOffset: CGFloat = 0
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
            if let tip {
                InfoTip(text: tip, xOffset: tipOffset)
            }
            Spacer()
            counterButton("minus") {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            }
            Text("\(value.wrappedValue)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 26)
            counterButton("plus") {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            }
        }
    }

    private func counterButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.fill))
        }
        .buttonStyle(.plain)
    }

    private func plainRow(
        _ label: String, _ value: String, tip: String? = nil, tipOffset: CGFloat = 0
    ) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            if let tip {
                InfoTip(text: tip, xOffset: tipOffset)
            }
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
        }
    }

    private func probRow(
        _ label: String, _ probability: Double, tip: String? = nil, tipOffset: CGFloat = 0
    ) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            if let tip {
                InfoTip(text: tip, xOffset: tipOffset)
            }
            Spacer()
            Text(String(format: "%.0f%%", min(probability, 1) * 100))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    probability >= 0.9
                        ? Color(red: 0.36, green: 0.80, blue: 0.44)
                        : probability >= 0.5 ? Theme.tierColor("A") : Theme.tierColor("S")
                )
        }
    }

    private func controlRow(
        _ label: String, value: String, @ViewBuilder control: () -> some View
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 30, alignment: .trailing)
            control()
        }
    }
}
