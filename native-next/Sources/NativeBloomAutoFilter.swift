import Foundation

/// BLOOM-REDESIGN-2026-11-16, variant B: filters derived from what was saved.
/// Nothing to assign, rename or keep in order.
enum NativeBloomAutoFilter: String, CaseIterable, Identifiable {
    case all, instagram, youtube, tiktok, web, notes, places

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Tutto"
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        case .tiktok: return "TikTok"
        case .web: return "Web"
        case .notes: return "Note"
        case .places: return "Luoghi"
        }
    }

    private static let social = ["instagram.com", "youtube.com", "youtu.be", "tiktok.com"]

    static func host(_ record: Record) -> String {
        let raw = record.text("urlString", fallback: record["noteLinks"]?.array.first?.string ?? "")
        return URL(string: raw)?.host?.lowercased() ?? ""
    }
    private static func belongs(_ host: String, to domains: [String]) -> Bool {
        domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    func matches(_ record: Record) -> Bool {
        let host = Self.host(record)
        switch self {
        case .all: return true
        case .instagram: return Self.belongs(host, to: ["instagram.com"])
        case .youtube: return Self.belongs(host, to: ["youtube.com", "youtu.be"])
        case .tiktok: return Self.belongs(host, to: ["tiktok.com"])
        case .web: return !host.isEmpty && !Self.belongs(host, to: Self.social)
        case .notes: return host.isEmpty && record.record("place").isEmpty
        case .places: return !record.record("place").isEmpty
        }
    }

    /// Only filters with at least one saved item are offered.
    static func available(in records: [Record]) -> [NativeBloomAutoFilter] {
        allCases.filter { filter in filter == .all || records.contains { filter.matches($0) } }
    }
}
