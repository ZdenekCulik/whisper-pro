import SwiftUI
import SwiftData

/// Full "English coach" page — its own sidebar item, moved out of the dashboard.
/// Lists every gentle correction the coach has picked up, newest first.
struct EnglishCoachView: View {
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("englishCoachEnabled") private var enabled = false
    @Query(sort: \CoachNote.timestamp, order: .reverse) private var notes: [CoachNote]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if enabled && !notes.isEmpty {
                    stackedSideNoteCard
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("English coach")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.resolvedPrimaryText)
                Text("Gentle corrections the coach picked up from your English dictations.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
            }

            Spacer()

            if enabled && !notes.isEmpty {
                Text("\(notes.count) learned")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.08)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stacked pair + side note

    private var stackedSideNoteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phrases learned")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(notes) { note in
                    stackedSideNoteRow(note)

                    if note.id != notes.last?.id {
                        Divider()
                            .overlay(theme.resolvedSecondaryText.opacity(0.10))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 28))
    }

    @ViewBuilder
    private func stackedSideNoteRow(_ note: CoachNote) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.said)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText.opacity(0.6))

                Text(note.corrected)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(AppTheme.Status.positive)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !note.why.isEmpty {
                Rectangle()
                    .fill(theme.resolvedSecondaryText.opacity(0.12))
                    .frame(width: 1)
                    .frame(minHeight: 30)

                Text(note.why)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText.opacity(0.75))
                    .frame(width: 168, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 13)
    }

    // MARK: - Empty state

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
                 : "Turn it on to start collecting gentle English tips.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if !enabled {
                HStack(spacing: 10) {
                    Button {
                        enabled = true
                    } label: {
                        Text("Turn on English coach")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        NotificationCenter.default.post(
                            name: .navigateToDestination,
                            object: nil,
                            userInfo: ["destination": ViewType.settings.rawValue]
                        )
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(AppCardBackground(cornerRadius: 28))
    }
}
