import Foundation

// MARK: - Models (mirror scripts/build_snapshot.py output)

struct Augment: Codable, Identifiable {
    let id: String
    let tier: String
    let name: String
    let desc: String
    let icon: String?
    let rarity: String
}

enum AugmentRarity: String, CaseIterable {
    case all, silver, gold, prismatic

    var label: String {
        switch self {
        case .all: return "All"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .prismatic: return "Prismatic"
        }
    }
}

struct ItemStat: Codable, Identifiable {
    let id: String
    let name: String
    let desc: String
    let icon: String?
    let category: String
    let avgPlace: Double
    let top4: Double
    let games: Int
}

enum ItemCategory: String, CaseIterable {
    case all, completed, radiant, artifact, emblem, component, other

    var label: String {
        switch self {
        case .all: return "All"
        case .completed: return "Completed"
        case .radiant: return "Radiant"
        case .artifact: return "Artifact"
        case .emblem: return "Emblem"
        case .component: return "Component"
        case .other: return "Other"
        }
    }
}

struct CompUnit: Codable, Hashable {
    let name: String
    let icon: String?
    let star3: Bool?
    let items: [String]?
}

struct CompAugmentRec: Codable, Hashable {
    let name: String
    let icon: String?
    let tier: String
}

struct Comp: Codable, Identifiable {
    let id: Int
    let title: String
    let units: [CompUnit]
    let traits: [String]?
    let style: String?
    let styleDetail: String?
    let augments: [CompAugmentRec]?
    let avgPlace: Double?
    let games: Int?

    /// "Reroll · Jax 3★", "Fast 9", or nil for standard tempo.
    var styleBadge: String? {
        switch style {
        case "reroll": return styleDetail.map { "Reroll · \($0)" } ?? "Reroll"
        case "fast9": return "Fast 9"
        default: return nil
        }
    }

    func matches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || units.contains { $0.name.localizedCaseInsensitiveContains(query) }
            || (traits ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

struct ShopOdds: Codable, Identifiable {
    let level: Int
    let odds: [Double]
    var id: Int { level }
}

/// Unit pool math inputs: copies of each unit in the shared bag,
/// and how many distinct shop units exist per cost tier.
struct PoolInfo: Codable {
    let bagSizes: [Int]
    let champCounts: [Int]
}

struct Champion: Codable, Identifiable, Hashable {
    let name: String
    let cost: Int
    let icon: String?
    var id: String { "\(name)-\(cost)" }
}

// MARK: - Store

@MainActor
final class MetaStore: ObservableObject {
    static let shared = MetaStore()

    @Published private(set) var augments: [Augment] = []
    @Published private(set) var items: [ItemStat] = []
    @Published private(set) var comps: [Comp] = []
    @Published private(set) var odds: [ShopOdds] = []
    @Published private(set) var pool: PoolInfo?
    @Published private(set) var champions: [Champion] = []

    /// Icon filename → item name, for hover labels on comp BiS icons
    /// (comps only store item icon paths, not names).
    private(set) var itemNamesByIcon: [String: String] = [:]

    let tierOrder = ["S", "A", "B", "C", "D"]

    var snapshotLabel: String {
        guard let url = Bundle.main.url(forResource: "augments", withExtension: "json"),
              let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return "bundled snapshot" }
        return "snapshot \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private init() {
        augments = Self.loadBundled("augments")
        items = Self.loadBundled("items")
        comps = Self.loadBundled("comps")
        odds = Self.loadBundled("odds")
        champions = Self.loadBundled("champions")
        if let url = Bundle.main.url(forResource: "pools", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            pool = try? JSONDecoder().decode(PoolInfo.self, from: data)
        }
        itemNamesByIcon = Dictionary(
            items.compactMap { item in item.icon.map { ($0, item.name) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func loadBundled<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data)
        else {
            assertionFailure("Missing bundled resource \(name).json")
            return []
        }
        return decoded
    }
}
