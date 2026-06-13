import Foundation

/// Pre-formatted dashboard statistics passed to a dashboard layout variant.
/// Every variant renders the time-saved headline plus these four stats exactly once —
/// the variant IS the complete stats presentation (no separate stat-card grid below it).
struct DashboardStats: Equatable {
    /// Already-formatted, e.g. "24 hours, 6 minutes" (or a fallback string when not loaded).
    let timeSaved: String
    /// e.g. "2 234" or "–"
    let sessions: String
    /// e.g. "79 744" or "–"
    let words: String
    /// e.g. "96" or "–"
    let wordsPerMinute: String
    /// e.g. "398 720" or "–"
    let keystrokes: String
    /// false until the real numbers have loaded (values are "–" placeholders).
    let hasLoaded: Bool

    /// Sample data for Xcode previews.
    static let sample = DashboardStats(
        timeSaved: "24 hours, 6 minutes",
        sessions: "2 234",
        words: "79 744",
        wordsPerMinute: "96",
        keystrokes: "398 720",
        hasLoaded: true
    )
}
