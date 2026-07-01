import SwiftUI

/// Top apps you dictate into: real macOS app icon · name · thin usage bar · count.
struct TopAppsList: View {
    let apps: [InsightsData.ModeSlice]
    var accent: Color
    var animate: Bool = true

    @EnvironmentObject var theme: ThemeManager
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            ForEach(apps) { app in
                row(app)
            }
        }
        .onAppear {
            guard animate else { progress = 1; return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { progress = 1 }
        }
    }

    private func row(_ app: InsightsData.ModeSlice) -> some View {
        HStack(spacing: 11) {
            AppIconImage(bundleId: app.bundleId, fallbackSymbol: app.symbol, size: 22)

            Text(app.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(theme.resolvedPrimaryText)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.resolvedSecondaryText.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(6, geo.size.width * app.fraction * progress), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 22)

            Text("\(Int((app.fraction * 100).rounded()))%")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(theme.resolvedSecondaryText)
                .frame(width: 34, alignment: .trailing)
        }
    }
}
