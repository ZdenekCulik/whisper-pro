import SwiftUI

/// Image-led dashboard variant in the Intercom "overview card" style: a tasteful dreamy
/// illustration sits as a side accent panel next to the time-saved headline and the four
/// stats — the image accents, it does not go full-bleed.
struct DreamOverviewView: View {
    let stats: DashboardStats
    @EnvironmentObject var theme: ThemeManager

    private let sideAssetCandidates = ["DreamAura", "DreamMeadow", "DreamFlowers"]

    var body: some View {
        let accent = theme.resolvedAccent ?? .accentColor

        HStack(alignment: .top, spacing: 20) {
            content(accent: accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            sideIllustration
                .frame(width: 200)
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
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1)
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
                statCell("Sessions", stats.sessions, "waveform", accent)
                statCell("Words", stats.words, "textformat", accent)
                statCell("Words / min", stats.wordsPerMinute, "speedometer", accent)
                statCell("Keystrokes", stats.keystrokes, "keyboard", accent)
            }
        }
    }

    private func statCell(_ label: String, _ value: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 10) {
            DashboardIconGlyph(systemName: icon, color: accent, size: 15, frameSize: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-1)
                    .foregroundColor(stats.hasLoaded ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.1)
                    .foregroundColor(theme.resolvedSecondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Side illustration

    private var sideIllustration: some View {
        DreamImage(candidates: sideAssetCandidates, skin: theme.skin)
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180)
            .overlay(
                // Soft inner glow so the panel feels like a window of light.
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.06)],
                    center: .center,
                    startRadius: 60,
                    endRadius: 160
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.resolvedBorder.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

// MARK: - Shared defensive image loader

/// Loads the first asset that exists from `candidates`; falls back to a themed
/// dreamy gradient so the view always renders even if generation never ran.
struct DreamImage: View {
    let candidates: [String]
    let skin: AppSkin

    var body: some View {
        Group {
            if let name = candidates.first(where: { NSImageExists($0) }) {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallbackGradient
            }
        }
        // Decorative backdrop — its scaled-to-fill frame overflows its container,
        // so it must never capture mouse clicks meant for nearby controls.
        .allowsHitTesting(false)
    }

    private var fallbackGradient: some View {
        LinearGradient(colors: fallbackColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                RadialGradient(colors: [.white.opacity(0.5), .clear], center: .topTrailing, startRadius: 10, endRadius: 320)
            )
    }

    private var fallbackColors: [Color] {
        switch skin {
        case .light, .system:
            return [Color(red: 0.96, green: 0.92, blue: 0.98), Color(red: 0.88, green: 0.95, blue: 0.93)]
        case .dark:
            return [Color(red: 0.20, green: 0.18, blue: 0.30), Color(red: 0.14, green: 0.22, blue: 0.26)]
        }
    }
}

/// Whether a named image asset is available in the bundle.
func NSImageExists(_ name: String) -> Bool {
    NSImage(named: name) != nil
}

#if DEBUG
#Preview("Dream Overview") {
    DreamOverviewView(stats: .sample)
        .environmentObject(ThemeManager())
        .padding(24)
        .frame(width: 760)
}
#endif
