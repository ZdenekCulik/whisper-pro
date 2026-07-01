import SwiftUI

// MARK: - Compact Claude
//
// COMPACT direction — superwhisper / Stripe / Raycast density. Everything visible
// at a glance, zero scroll, strict 8pt grid. One hero number leads (time saved);
// four secondary stats sit in a tight balanced 2×2 grid below it. Restrained color:
// the accent touches only the hero number. Cards use the app's native material for
// Light/Dark and a flat surface fill for Warm/Midnight so all four skins read right.

struct CompactClaudeView: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    private var accent: Color { theme.resolvedAccent ?? Color.accentColor }
    private var usesNativeCard: Bool { theme.skin == .light || theme.skin == .dark || theme.skin == .system }

    private var statItems: [(label: String, value: String, icon: String)] {
        [
            ("Sessions", stats.sessions, "mic.fill"),
            ("Words", stats.words, "text.word.spacing"),
            ("Words per minute", stats.wordsPerMinute, "gauge.with.dots.needle.67percent"),
            ("Keystrokes", stats.keystrokes, "keyboard")
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            heroCard
            statGrid
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                eyebrow("Time saved with Whisper Pro")

                Text(stats.timeSaved)
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("That's focus you got back, one dictation at a time.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(accent.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(cornerRadius: 14))
    }

    // MARK: Stat grid

    private var statGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(Array(statItems.enumerated()), id: \.offset) { _, item in
                statCell(label: item.label, value: item.value, icon: item.icon)
            }
        }
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CountingNumberText(value, tracking: -1)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.resolvedSecondaryText)
                statLabel(label)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBackground(cornerRadius: 12))
    }

    // MARK: Shared pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.1)
            .foregroundStyle(theme.resolvedSecondaryText)
            .lineLimit(1)
    }

    private func statLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.1)
            .foregroundStyle(theme.resolvedSecondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func cardBackground(cornerRadius: CGFloat) -> some View {
        if usesNativeCard {
            AppCardBackground(cornerRadius: cornerRadius)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(theme.resolvedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(theme.resolvedBorder, lineWidth: 1)
                )
        }
    }
}

#Preview("Compact Claude · skins") {
    HStack(alignment: .top, spacing: 20) {
        ForEach(AppSkin.allCases) { skin in
            CompactClaudeView(stats: .sample)
                .environmentObject(ThemeManager(skin: skin, fontChoice: .system))
                .frame(width: 340)
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))
                .preferredColorScheme(skin.colorScheme)
        }
    }
    .padding(24)
    .fixedSize()
}
