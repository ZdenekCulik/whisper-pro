import SwiftUI

/// SPOTLIGHT dashboard variant — a Spotify-Wrapped-style celebratory moment.
/// The time-saved hero gets one confident, beautiful beat; the four stats sit
/// quietly beneath as identical pill chips. Renders all five numbers exactly once.
struct SpotlightClaudeView: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    private var accent: Color { theme.resolvedAccent ?? Color.accentColor }
    private var onDarkSkin: Bool { theme.skin.colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            hero
            chipsRow
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You saved this much time")
                .font(.system(size: 14, weight: .medium))
                .tracking(0.1)
                .foregroundColor(theme.resolvedSecondaryText)

            Text(stats.timeSaved)
                .font(.system(size: 52, weight: .heavy))
                .tracking(-1)
                .foregroundColor(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .redacted(reason: stats.hasLoaded ? [] : .placeholder)

            Text("That's typing you never had to do.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(theme.resolvedSecondaryText.opacity(0.85))
        }
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(theme.resolvedSurface)
            .overlay(
                RadialGradient(
                    colors: [accent.opacity(onDarkSkin ? 0.16 : 0.10), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 360
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.resolvedBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Chips

    private var chipsRow: some View {
        HStack(spacing: 10) {
            chip(value: stats.sessions, label: "Sessions")
            chip(value: stats.words, label: "Words")
            chip(value: stats.wordsPerMinute, label: "WPM")
            chip(value: stats.keystrokes, label: "Keystrokes")
        }
    }

    private func chip(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .tracking(-1)
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .redacted(reason: stats.hasLoaded ? [] : .placeholder)

            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(0.1)
                .foregroundColor(theme.resolvedSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(onDarkSkin ? 0.10 : 0.07))
        )
    }
}

#if DEBUG
#Preview("Spotlight") {
    SpotlightClaudeView(stats: .sample)
        .environmentObject(ThemeManager(skin: .dark, fontChoice: .system))
        .frame(width: 480)
        .padding()
}
#endif
