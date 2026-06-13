import Foundation

/// The dashboard layout the user picked (in Settings → Interface).
/// Raw values are kept stable (2/3/8) so existing stored preferences map correctly.
enum DashboardHeroVariant: Int, CaseIterable, Identifiable {
    case compact = 2
    case spotlight = 3
    case image = 8

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .compact: return "Compact"
        case .spotlight: return "Spotlight"
        case .image: return "Image"
        }
    }
}
