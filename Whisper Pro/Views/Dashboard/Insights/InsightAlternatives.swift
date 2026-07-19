import SwiftUI
import Charts

/// WPM viz, option B: a single speedometer track with a marker showing where you
/// land between "typing slow" and "talking fast", plus a percentile read-out.
struct WpmComparisonB: View {
    let wpm: Int
    var accent: Color
    @EnvironmentObject var theme: ThemeManager

    private let scaleMax = 160.0
    private var position: Double { min(1, Double(wpm) / scaleMax) }
    private var multiple: Double { Double(wpm) / 40.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let x = geo.size.width * position
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.resolvedSecondaryText.opacity(0.18), accent],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 10)
                        .offset(y: 13)

                    // Marker
                    Capsule()
                        .fill(theme.resolvedPrimaryText)
                        .frame(width: 4, height: 20)
                        .offset(x: x - 2, y: 8)

                    // Value bubble
                    Text("\(wpm)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accent))
                        .offset(x: max(0, x - 14), y: -10)
                }
            }
            .frame(height: 36)

            HStack {
                Text("Typing 40")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
                Spacer()
                Text("Talking 150")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.resolvedSecondaryText)
            }
        }
        .help(String(format: "%.1f× faster than typing · top 22%%", multiple))
    }
}

/// Mode-panel alternative (2): when in the day you dictate most.
/// Styled after native macOS charts (Screen Time, Battery in System Settings):
/// small-radius bars, a muted track for empty hours, subtle gridlines and a
/// baseline, small secondary-color axis labels in 24h form (00, 06, 12, 18).
struct InsightTimeOfDay: View {
    let hours: [InsightsData.TrendPoint]
    var accent: Color
    @EnvironmentObject var theme: ThemeManager

    private var peakHour: Int {
        hours.max { $0.value < $1.value }?.index ?? 12
    }

    private var maxValue: Double {
        hours.map(\.value).max() ?? 0
    }

    private func axisLabel(_ hour: Int) -> String {
        String(format: "%02d", hour)
    }

    private func clockLabel(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12) \(hour < 12 ? "AM" : "PM")"
    }

    var body: some View {
        Chart(hours) { point in
            BarMark(
                x: .value("hour", point.index),
                y: .value("words", point.value),
                width: .fixed(7)
            )
            .cornerRadius(2.5)
            .foregroundStyle(
                point.value > 0
                    ? accent.opacity(point.index == peakHour ? 0.95 : 0.42)
                    : theme.resolvedSecondaryText.opacity(0.12)
            )
        }
        .chartYScale(domain: 0...max(maxValue, 1))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(theme.resolvedBorder.opacity(0.28))
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisGridLine().foregroundStyle(theme.resolvedBorder.opacity(0.5))
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(axisLabel(hour))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.resolvedSecondaryText)
                    }
                }
            }
        }
        .frame(height: 104)
        .help("You dictate most around \(clockLabel(peakHour))")
    }
}
