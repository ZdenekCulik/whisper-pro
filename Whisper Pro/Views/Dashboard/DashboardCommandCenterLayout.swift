import SwiftUI

// MARK: - Command Center
//
// COMMAND CENTER direction — Linear / Raycast bento grid. A tight, data-dense
// dashboard built from differently-weighted cards on a strict grid:
//   • a tall HERO card (time saved headline + accent value + an animated bar
//     sparkline) anchoring the left column,
//   • a STREAK / achievement card with the holographic lightning sticker,
//   • a wide WEEK-ACTIVITY heatmap strip,
//   • four compact METRIC tiles (sessions, words, WPM, keystrokes) — each stat
//     rendered exactly once — sitting in a balanced 2×2 cluster.
// Sharp corners, hairline borders, restrained color: the accent only touches the
// hero number, sparkline and heatmap. Cards use the app's native material for
// Light/Dark and a flat surface fill so all skins read right.

struct DashboardCommandCenterLayout: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.colorScheme) private var environmentColorScheme

    private var accent: Color { theme.resolvedAccent ?? .accentColor }

    /// Dark-aware: respects the chosen skin, but falls back to the live
    /// environment colour scheme when the skin is `.system`.
    private var isDark: Bool {
        (theme.skin.colorScheme ?? environmentColorScheme) == .dark
    }

    // Deterministic pseudo-activity so the heatmap / sparkline always look alive.
    // Derived from the formatted words string so it stays stable per data set.
    private var seed: Int {
        stats.words.unicodeScalars.reduce(7) { $0 &+ Int($1.value) }
    }

    private var weekActivity: [Double] {
        (0..<7).map { i in
            guard stats.hasLoaded else { return 0.12 }
            let raw = Double((seed &* (i + 3)) % 97) / 97.0
            return 0.22 + raw * 0.78
        }
    }

    private var sparkSamples: [Double] {
        (0..<14).map { i in
            guard stats.hasLoaded else { return 0.2 }
            let raw = Double((seed &* (i + 5) &+ i &* 13) % 89) / 89.0
            return 0.18 + raw * 0.82
        }
    }

    private let weekdayInitials = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 12) {
            // Top row: tall hero + streak side car
            HStack(alignment: .top, spacing: 12) {
                heroCard
                    .frame(maxWidth: .infinity)
                streakCard
                    .frame(width: 168)
            }

            // Activity heatmap strip
            activityCard

            // Metric cluster — all four stats, once each
            metricCluster
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow("Time saved")

            Text(stats.timeSaved)
                .font(.system(size: 40, weight: .bold))
                .tracking(-1)
                .foregroundStyle(stats.hasLoaded ? accent : theme.resolvedSecondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("Focus you got back, one dictation at a time.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(theme.resolvedSecondaryText)
                .lineLimit(2)
                .padding(.top, 6)

            Spacer(minLength: 16)

            sparkline
                .frame(height: 46)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
        .background(cardBackground(cornerRadius: 16))
    }

    private var sparkline: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let n = max(sparkSamples.count - 1, 1)
            let step = w / CGFloat(n)

            ZStack {
                // Filled area
                areaPath(in: CGSize(width: w, height: h), step: step)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.28), accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // Stroke line
                linePath(in: CGSize(width: w, height: h), step: step)
                    .stroke(
                        accent.opacity(stats.hasLoaded ? 0.9 : 0.3),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    private func linePath(in size: CGSize, step: CGFloat) -> Path {
        var path = Path()
        for (i, value) in sparkSamples.enumerated() {
            let x = CGFloat(i) * step
            let y = size.height - CGFloat(value) * size.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func areaPath(in size: CGSize, step: CGFloat) -> Path {
        var path = linePath(in: size, step: step)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    // MARK: Streak

    private var streakCard: some View {
        VStack(spacing: 8) {
            StickerAchievementBadge()
                .frame(width: 56, height: 70)

            Text("On a roll".uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(theme.resolvedPrimaryText)

            Text("Keep the streak alive")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(theme.resolvedSecondaryText.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 188)
        .padding(.horizontal, 14)
        .background(cardBackground(cornerRadius: 16))
    }

    // MARK: Activity heatmap

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                eyebrow("This week")
                Spacer()
                Text(stats.hasLoaded ? "Activity" : "—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.resolvedSecondaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent.opacity(0.10 + weekActivity[i] * 0.55))
                            .frame(height: 34)

                        Text(weekdayInitials[i])
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.resolvedSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(cornerRadius: 16))
    }

    // MARK: Metric cluster

    private var metricCluster: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            metricTile(icon: "mic.fill", value: stats.sessions, label: "Sessions", tint: AppTheme.Status.positive)
            metricTile(icon: "text.word.spacing", value: stats.words, label: "Words", tint: accent)
            metricTile(icon: "gauge.with.dots.needle.67percent", value: stats.wordsPerMinute, label: "WPM", tint: AppTheme.Status.infoStrong)
            metricTile(icon: "keyboard", value: stats.keystrokes, label: "Keystrokes", tint: AppTheme.Sidebar.dictionary)
        }
    }

    private func metricTile(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            DashboardIconGlyph(systemName: icon, color: tint, size: 16, frameSize: 24)

            CountingNumberText(value, tracking: -0.5)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(stats.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.45)
                .foregroundStyle(theme.resolvedSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .background(cardBackground(cornerRadius: 14))
    }

    // MARK: Shared pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(theme.resolvedSecondaryText)
            .lineLimit(1)
    }

    @ViewBuilder
    private func cardBackground(cornerRadius: CGFloat) -> some View {
        if theme.skin == .light || theme.skin == .dark || theme.skin == .system {
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

#if DEBUG
#Preview("Command Center · skins") {
    HStack(alignment: .top, spacing: 20) {
        ForEach(AppSkin.allCases) { skin in
            DashboardCommandCenterLayout(stats: .sample)
                .environmentObject(ThemeManager(skin: skin, fontChoice: .system))
                .frame(width: 460)
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))
                .preferredColorScheme(skin.colorScheme)
        }
    }
    .padding(24)
    .fixedSize()
}
#endif
