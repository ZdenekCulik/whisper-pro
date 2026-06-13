import SwiftUI
import SwiftData

struct RecentTranscriptsSection: View {
    @EnvironmentObject var theme: ThemeManager

    @Query private var transcriptions: [Transcription]

    init() {
        let calendar = Calendar.current
        let startOfDayMinus2 = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        )
        var descriptor = FetchDescriptor<Transcription>(
            predicate: #Predicate { $0.timestamp >= startOfDayMinus2 },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        _transcriptions = Query(descriptor)
    }

    // Group by calendar day, newest day first
    private var grouped: [(date: Date, items: [Transcription])] {
        let calendar = Calendar.current
        var dict: [Date: [Transcription]] = [:]
        for t in transcriptions {
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
            // Section title — matches HelpAndResourcesSection header style
            Text("Recent")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)

            if grouped.isEmpty {
                Text("No recent dictations yet.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
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
