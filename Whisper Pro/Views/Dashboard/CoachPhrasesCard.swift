import SwiftUI
import SwiftData

/// Dashboard collection of phrases the English coach has taught you.
/// Hidden when the coach is off or nothing has been learned yet.
struct CoachPhrasesCard: View {
    @EnvironmentObject var theme: ThemeManager
    @AppStorage("englishCoachEnabled") private var enabled = false
    @Query(sort: \CoachNote.timestamp, order: .reverse) private var notes: [CoachNote]

    private let green = Color(red: 0.30, green: 0.80, blue: 0.45)

    var body: some View {
        if enabled && !notes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("English coach")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.resolvedPrimaryText)
                    Spacer()
                    Text("\(notes.count) learned")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.resolvedSecondaryText)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(notes.prefix(6)) { note in
                        row(note)
                        if note.id != notes.prefix(6).last?.id {
                            Divider().overlay(theme.resolvedSecondaryText.opacity(0.12))
                        }
                    }
                }
            }
            .padding(18)
            .background(AppCardBackground(cornerRadius: 28))
        }
    }

    private func row(_ note: CoachNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(note.said)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.resolvedSecondaryText.opacity(0.7))
                Text(note.corrected)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(green)
            }
            if !note.why.isEmpty {
                Text(note.why)
                    .font(.custom("Bradley Hand", size: 13).weight(.semibold))
                    .foregroundColor(theme.resolvedSecondaryText.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
