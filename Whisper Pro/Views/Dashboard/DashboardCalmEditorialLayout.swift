import SwiftUI

// MARK: - Calm Editorial
//
// CALM EDITORIAL direction — a spacious, typography-led journal dashboard.
// The opposite of dense: a small eyebrow leads, the time-saved value reads like
// a serene pull-quote, and the four numbers collapse into a single understated
// stat line (not a card grid). Generous whitespace, hairline dividers, almost
// no chrome on the hero itself. This is the COMPLETE hero + stats presentation;
// the greeting above and the recent-transcripts feed below are owned by
// DashboardContent, so neither is repeated here.

struct DashboardCalmEditorialLayout: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    private var accent: Color { theme.resolvedAccent ?? Color.accentColor }

    private var statItems: [(label: String, value: String)] {
        [
            ("Sessions", stats.sessions),
            ("Words", stats.words),
            ("Words / min", stats.wordsPerMinute),
            ("Keystrokes", stats.keystrokes)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            hero
            statLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Hero — editorial headline + pull-quote value

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Eyebrow above the pull-quote. (The greeting headline is owned by
            // DashboardContent above this layout, so it is not repeated here.)
            Text("Time saved with Whisper Pro")
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(theme.resolvedSecondaryText)

            // The value reads like a serene editorial pull-quote.
            Text(stats.timeSaved)
                .font(.system(size: 52, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            // Quiet supporting line.
            Text("Quiet hours handed back to you, one dictation at a time.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.resolvedSecondaryText)
                .lineSpacing(2)
                .frame(maxWidth: 460, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: Stat line — one understated row, hairline-separated

    private var statLine: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(theme.resolvedBorder.opacity(0.6))
                .frame(height: 1)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(Array(statItems.enumerated()), id: \.offset) { index, item in
                    statColumn(label: item.label, value: item.value)

                    if index < statItems.count - 1 {
                        Spacer(minLength: 12)
                    }
                }
            }

            Rectangle()
                .fill(theme.resolvedBorder.opacity(0.6))
                .frame(height: 1)
        }
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CountingNumberText(value, tracking: -0.5)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Calm Editorial · skins") {
    HStack(alignment: .top, spacing: 24) {
        ForEach(AppSkin.allCases) { skin in
            DashboardCalmEditorialLayout(stats: .sample)
                .environmentObject(ThemeManager(skin: skin, fontChoice: .system))
                .frame(width: 420)
                .padding(28)
                .background(Color(NSColor.windowBackgroundColor))
                .preferredColorScheme(skin.colorScheme)
        }
    }
    .padding(28)
    .fixedSize()
}
