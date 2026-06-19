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
struct InsightTimeOfDay: View {
    let hours: [InsightsData.TrendPoint]
    var accent: Color
    @EnvironmentObject var theme: ThemeManager

    private var peakHour: Int {
        hours.max { $0.value < $1.value }?.index ?? 12
    }

    private func clockLabel(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12) \(hour < 12 ? "AM" : "PM")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(hours) { point in
                BarMark(
                    x: .value("hour", point.index),
                    y: .value("words", point.value),
                    width: .fixed(9)
                )
                .clipShape(Capsule())
                .foregroundStyle(point.index == peakHour ? accent : accent.opacity(0.3))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(clockLabel(hour))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(theme.resolvedSecondaryText)
                        }
                    }
                }
            }
            .frame(height: 104)
        }
        .help("You dictate most around \(clockLabel(peakHour))")
    }
}
