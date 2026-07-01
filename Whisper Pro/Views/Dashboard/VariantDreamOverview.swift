import SwiftUI

/// Image-led dashboard variant in the Intercom "overview card" style: a holographic
/// Sticker-style badge sits next to the time-saved headline and the four stats.
struct DreamOverviewView: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        let accent = theme.resolvedAccent ?? .accentColor

        // The holographic lightning sticker now lives once, in the Insights
        // activity panel where it's tied to the streak — not duplicated here.
        HStack(alignment: .top, spacing: 20) {
            content(accent: accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(AppCardBackground(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.resolvedBorder.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: Left content

    private func content(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Time saved with Whisper Pro".uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.1)
                    .foregroundColor(theme.resolvedSecondaryText)

                Text(stats.timeSaved)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.5)
                    .foregroundColor(theme.resolvedPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .overlay(theme.resolvedBorder.opacity(0.6))

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 16
            ) {
                statCell("Sessions", stats.sessions, "mic.fill", accent)
                statCell("Words", stats.words, "text.alignleft", accent)
                statCell("Words / min", stats.wordsPerMinute, "speedometer", accent)
                statCell("Keystrokes", stats.keystrokes, "keyboard", accent)
            }
        }
    }

    private func statCell(_ label: String, _ value: String, _ icon: String, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 16)

                CountingNumberText(value, tracking: -0.5)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(stats.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.1)
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

#if DEBUG
#Preview("Dream Overview") {
    DreamOverviewView(stats: .sample)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 760)
}
#endif

// MARK: - V5 Passport

private struct DashboardPassportStatStrip: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            stat(stats.sessions, "Sessions")
            stat(stats.words, "Words")
            stat(stats.wordsPerMinute, "WPM")
            stat(stats.keystrokes, "Keystrokes")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CountingNumberText(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(stats.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.resolvedSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProductivityPassportOverviewView: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        let accent = theme.resolvedAccent ?? .accentColor

        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Productivity passport".uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.resolvedSecondaryText)
                        .lineLimit(1)

                    Text(stats.timeSaved)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(theme.resolvedPrimaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    Text("A clean little proof card for your voice workflow.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.resolvedSecondaryText)
                        .lineLimit(2)
                }

                Divider()
                    .overlay(theme.resolvedBorder.opacity(0.65))

                DashboardPassportStatStrip(stats: stats)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            passportCard(accent: accent)
                .frame(width: 220, height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(accent.opacity(theme.skin.colorScheme == .dark ? 0.12 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(theme.resolvedBorder.opacity(0.65), lineWidth: 1)
                )
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppCardBackground(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.resolvedBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private func passportCard(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text("PRO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent.opacity(0.12)))
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 5) {
                Text("Power Dictator")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.resolvedPrimaryText)
                Text("\(stats.sessions) sessions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.resolvedSecondaryText)
            }

            Divider()
                .overlay(theme.resolvedBorder)

            Text("Whisper Pro achievement card")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolvedSecondaryText)
                .textCase(.uppercase)
        }
        .padding(22)
    }
}
