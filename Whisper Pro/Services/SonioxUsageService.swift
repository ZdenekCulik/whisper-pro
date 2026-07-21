import Foundation

/// Fetches Soniox usage-log spend so the dashboard can show a remaining-budget
/// pill. Soniox has no balance endpoint, only usage-logs: the user types their
/// current balance into Settings once, and we subtract every dollar spent since
/// that date. Result is cached in memory and refreshed at most every 15 minutes.
struct SonioxUsageResult {
    var spentSinceBalanceDate: Double
    var spentThisMonth: Double
}

enum SonioxUsageService {
    private static let baseURL = "https://api.soniox.com/v1/usage-logs"
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static var cachedResult: SonioxUsageResult?
    private static var lastFetch: Date?
    private static let refreshInterval: TimeInterval = 15 * 60

    /// Returns the cached result if it's fresh enough, otherwise fetches new
    /// totals from Soniox. On any failure, falls back to the last cached value.
    static func fetchUsage(apiKey: String, balanceSetDate: Date) async -> SonioxUsageResult? {
        if let cachedResult, let lastFetch, Date().timeIntervalSince(lastFetch) < refreshInterval {
            return cachedResult
        }

        let now = Date()
        do {
            async let sinceBalance = totalCost(apiKey: apiKey, from: clampedStart(balanceSetDate, now: now), to: now)
            async let thisMonth = totalCost(apiKey: apiKey, from: startOfMonth(now), to: now)
            let result = SonioxUsageResult(spentSinceBalanceDate: try await sinceBalance, spentThisMonth: try await thisMonth)
            cachedResult = result
            lastFetch = now
            return result
        } catch {
            return cachedResult
        }
    }

    /// Soniox rejects windows over 91 days back or longer than 31 days per
    /// request, so a start date older than that is clamped (making the result
    /// an approximation, which is acceptable per the spec).
    private static func clampedStart(_ date: Date, now: Date) -> Date {
        let maxLookback = now.addingTimeInterval(-91 * 24 * 60 * 60)
        return max(date, maxLookback)
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Sums cost_usd across every usage-log entry between `start` and `end`,
    /// chunking into <=31-day windows and following next_page_cursor within
    /// each chunk.
    private static func totalCost(apiKey: String, from start: Date, to end: Date) async throws -> Double {
        guard start < end else { return 0 }
        var total = 0.0
        var chunkStart = start
        let maxChunk: TimeInterval = 31 * 24 * 60 * 60

        while chunkStart < end {
            let chunkEnd = min(chunkStart.addingTimeInterval(maxChunk), end)
            total += try await totalCostForChunk(apiKey: apiKey, start: chunkStart, end: chunkEnd)
            chunkStart = chunkEnd
        }
        return total
    }

    private static func totalCostForChunk(apiKey: String, start: Date, end: Date) async throws -> Double {
        var total = 0.0
        var cursor: String?

        repeat {
            var components = URLComponents(string: baseURL)!
            var queryItems = [
                URLQueryItem(name: "start_time", value: isoFormatter.string(from: start)),
                URLQueryItem(name: "end_time", value: isoFormatter.string(from: end)),
                URLQueryItem(name: "limit", value: "1000")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            components.queryItems = queryItems

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let page = try JSONDecoder().decode(SonioxUsageLogsPage.self, from: data)
            total += page.usage_logs.reduce(0) { $0 + (Double($1.cost_usd) ?? 0) }
            cursor = page.next_page_cursor
        } while cursor != nil

        return total
    }
}

private struct SonioxUsageLogsPage: Decodable {
    var usage_logs: [SonioxUsageLogEntry]
    var next_page_cursor: String?
}

private struct SonioxUsageLogEntry: Decodable {
    /// Soniox returns cost as a decimal string (e.g. "0.0081000000"), not a number.
    var cost_usd: String
}
