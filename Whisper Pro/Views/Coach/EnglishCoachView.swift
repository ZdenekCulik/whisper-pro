import SwiftUI
import SwiftData

/// Full "English coach" page — its own sidebar item, moved out of the dashboard.
/// Lists every gentle correction the coach has picked up, newest first.
struct EnglishCoachView: View {
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("englishCoachEnabled") private var enabled = false
    @Query(sort: \CoachNote.timestamp, order: .reverse) private var notes: [CoachNote]

    private let green = Color(red: 0.30, green: 0.80, blue: 0.45)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if enabled && !notes.isEmpty {
                    phrasesCard
                } else {
                    emptyState
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("English coach")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.resolvedPrimaryText)
            Text("Gentle corrections the coach picked up from your English dictations.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phrasesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Phrases learned")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.resolvedPrimaryText)
                Spacer()
                Text("\(notes.count) learned")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(notes) { note in
                    row(note)
                    if note.id != notes.last?.id {
                        Divider().overlay(theme.resolvedSecondaryText.opacity(0.12))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 28))
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "graduationcap")
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(theme.resolvedSecondaryText.opacity(0.5))
            Text(enabled ? "No corrections yet" : "English coach is off")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)
            Text(enabled
                 ? "Keep dictating in English — helpful tweaks will show up here."
                 : "Turn the coach on in Settings to start collecting gentle English tips.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(AppCardBackground(cornerRadius: 28))
    }
}
