import SwiftUI
import SwiftData

struct RecentTranscriptsSection: View {
    @EnvironmentObject var theme: ThemeManager

    @Query private var transcriptions: [Transcription]

    init() {
        // Show the most recent 200 transcripts regardless of date (not just the
        // last couple of days), newest first.
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        _transcriptions = Query(descriptor)
    }

    // Drop empty/blank transcriptions (e.g. cancelled or failed recordings) so the
    // Recent list never shows a bare timestamp with no text.
    private func hasText(_ t: Transcription) -> Bool {
        let value = t.enhancedText ?? t.text
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Group by calendar day, newest day first
    private var grouped: [(date: Date, items: [Transcription])] {
        let calendar = Calendar.current
        var dict: [Date: [Transcription]] = [:]
        for t in transcriptions where hasText(t) {
            let day = calendar.startOfDay(for: t.timestamp)
            dict[day, default: []].append(t)
        }
        return dict
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "TODAY" }
        if calendar.isDateInYesterday(date) { return "YESTERDAY" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent transcripts")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)

            if grouped.isEmpty {
                Text("No recent dictations yet.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(grouped, id: \.date) { group in
                        // Day header
                        Text(dayLabel(for: group.date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.resolvedSecondaryText)
                            .kerning(0.5)
                            .padding(.top, group.date == grouped.first?.date ? 0 : 16)
                            .padding(.bottom, 4)

                        // Rows for that day
                        ForEach(group.items) { transcription in
                            RecentTranscriptRow(transcription: transcription)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(AppCardBackground(cornerRadius: 28))
    }
}
