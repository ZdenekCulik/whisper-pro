import SwiftUI

/// Animated horizontal progress bars showing how dictation splits across modes.
/// Mirrors the "Desktop usage" panel: icon · animated fill with percent · count.
struct InsightModeBars: View {
    let modes: [InsightsData.ModeSlice]
    var accent: Color
    /// When false (screenshots/tests) bars render filled immediately.
    var animate: Bool = true

    @EnvironmentObject var theme: ThemeManager
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            ForEach(modes) { mode in
                row(mode)
            }
        }
        .onAppear {
            guard animate else { progress = 1; return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { progress = 1 }
        }
    }

    private func row(_ mode: InsightsData.ModeSlice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mode.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.resolvedSecondaryText)
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.resolvedSecondaryText.opacity(0.1))
                    Capsule()
                        .fill(accent.opacity(0.9))
                        .frame(width: max(28, geo.size.width * mode.fraction * progress))
                        .overlay(alignment: .leading) {
                            Text("\(Int((mode.fraction * 100).rounded()))%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.leading, 10)
                                .opacity(mode.fraction > 0.08 ? 1 : 0)
                        }
                }
            }
            .frame(height: 24)

            Text("\(mode.count) \(mode.name)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .frame(width: 130, alignment: .leading)
                .lineLimit(1)
        }
    }
}
