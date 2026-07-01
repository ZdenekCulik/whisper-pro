import SwiftUI
import Charts

/// Half-circle gauge (the "Words per minute" arc).
struct MiniGauge: View {
    /// 0...1 fill of the half arc.
    var value: Double
    var accent: Color
    var caption: String
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ZStack {
            arc(from: 0, to: 1)
                .stroke(theme.resolvedSecondaryText.opacity(0.12), style: .init(lineWidth: 10, lineCap: .round))
            arc(from: 0, to: max(0.02, min(1, value)))
                .stroke(accent, style: .init(lineWidth: 10, lineCap: .round))
            Text(caption)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.resolvedPrimaryText)
                .offset(y: 14)
        }
        .frame(width: 120, height: 70)
    }

    private func arc(from: Double, to: Double) -> Path {
        Path { p in
            let rect = CGRect(x: 5, y: 5, width: 110, height: 110)
            p.addArc(
                center: CGPoint(x: rect.midX, y: rect.maxY - 5),
                radius: 55,
                startAngle: .degrees(180 + from * 180),
                endAngle: .degrees(180 + to * 180),
                clockwise: false
            )
        }
    }
}

/// Compact accent sparkline for a single metric tile.
struct Sparkline: View {
    let points: [InsightsData.TrendPoint]
    var accent: Color
    var height: CGFloat = 34

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("i", point.index),
                y: .value("v", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [accent.opacity(0.32), accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("i", point.index),
                y: .value("v", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(accent)
            .lineStyle(.init(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}

/// Small up/down delta pill, e.g. "↗ 24% this month".
struct DeltaBadge: View {
    let percent: Int
    @EnvironmentObject var theme: ThemeManager

    private var isUp: Bool { percent >= 0 }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(abs(percent))% this month")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(theme.resolvedSecondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.resolvedSecondaryText.opacity(0.08)))
    }
}
