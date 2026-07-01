import Foundation

/// Pre-formatted dashboard statistics passed to a dashboard layout variant.
/// Every variant renders the time-saved headline plus these four stats exactly once —
/// the variant IS the complete stats presentation (no separate stat-card grid below it).
struct DashboardStats: Equatable {
    /// Already-formatted, e.g. "24 hours, 6 minutes" (or a fallback string when not loaded).
    let timeSaved: String
    /// Raw all-time time saved in seconds, so range-aware views can scale it.
    let timeSavedSeconds: TimeInterval
    /// e.g. "2 234" or "–"
    let sessions: String
    /// e.g. "79 744" or "–"
    let words: String
    /// e.g. "96" or "–"
    let wordsPerMinute: String
    /// e.g. "398 720" or "–"
    let keystrokes: String
    /// Words dictated in the last 24 hours, e.g. "1 240" or "–". Shown on the Overview layout.
    /// Layouts that don't compute it (e.g. the Stats page) pass "–".
    let wordsToday: String
    /// false until the real numbers have loaded (values are "–" placeholders).
    let hasLoaded: Bool

    /// Sample data for Xcode previews.
    static let sample = DashboardStats(
        timeSaved: "24 hours, 6 minutes",
        timeSavedSeconds: 24 * 3600 + 6 * 60,
        sessions: "2 234",
        words: "79 744",
        wordsPerMinute: "96",
        keystrokes: "398 720",
        wordsToday: "1 240",
        hasLoaded: true
    )
}
