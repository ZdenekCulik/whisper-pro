import Foundation

enum DashboardHeroVariant: Int, CaseIterable, Identifiable {
    case achievement = 1
    case compact = 2
    case spotlight = 3
    case milestone = 4
    case passport = 5
    case logo = 6
    case quiet = 7
    case image = 8
    case commandCenter = 9
    case calmEditorial = 10
    case overview = 11   // the original stats + streak + sticker dashboard

    var id: Int { rawValue }

    static var editorialClaude: DashboardHeroVariant { .achievement }

    /// Only layouts that render a genuinely distinct look — shown in the picker.
    /// (achievement≈compact, milestone≈spotlight, quiet/image≈dream were duplicates.)
    static let selectable: [DashboardHeroVariant] = [
        .overview, .compact, .spotlight, .passport, .logo, .commandCenter, .calmEditorial
    ]

    init(storedValue: Int) {
        self = DashboardHeroVariant(rawValue: storedValue) ?? .overview
    }

    var label: String {
        "V\(rawValue)"
    }

    var displayName: String {
        switch self {
        case .achievement: return "Achievement"
        case .compact: return "Compact"
        case .spotlight: return "Spotlight"
        case .milestone: return "Milestone"
        case .passport: return "Passport"
        case .logo: return "Dream"
        case .quiet: return "Quiet"
        case .image: return "Image"
        case .commandCenter: return "Command Center"
        case .calmEditorial: return "Calm Editorial"
        case .overview: return "Overview"
        }
    }
}
