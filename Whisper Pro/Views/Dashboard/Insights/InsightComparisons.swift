import SwiftUI
import Charts

/// Answers "is this fast?" by ranking your dictation speed against typing and talking.
/// Typing ≈ 40 wpm, conversational speech ≈ 150 wpm — your number sits between.
struct WpmComparison: View {
    let wpm: Int
    var accent: Color
    @EnvironmentObject var theme: ThemeManager

    private let typing = 40
    private let talking = 150
    private var scaleMax: Double { Double(max(talking, wpm)) }

    private var multiple: Double { Double(wpm) / Double(typing) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            bar("Typing", typing, highlighted: false)
            bar("You", wpm, highlighted: true)
            bar("Talking", talking, highlighted: false)

            Text(String(format: "%.1f× faster than typing", multiple))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent)
                .padding(.top, 2)
        }
    }

    private func bar(_ label: String, _ value: Int, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.resolvedSecondaryText)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.resolvedSecondaryText.opacity(0.1))
                    Capsule()
                        .fill(highlighted ? accent : theme.resolvedSecondaryText.opacity(0.35))
                        .frame(width: max(6, geo.size.width * (Double(value) / scaleMax)))
                }
            }
            .frame(height: 10)

            Text("\(value)")
                .font(.system(size: 11, weight: highlighted ? .bold : .medium))
                .foregroundColor(highlighted ? theme.resolvedPrimaryText : theme.resolvedSecondaryText)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

/// Running-total line that only ever climbs, with dots marking the biggest jumps.
struct CumulativeWordsChart: View {
    /// Per-period word increments (oldest first).
    let increments: [InsightsData.TrendPoint]
    var accent: Color
    var height: CGFloat = 60

    /// Cumulative running total.
    private var cumulative: [InsightsData.TrendPoint] {
        var total = 0.0
        return increments.map { point in
            total += point.value
            return InsightsData.TrendPoint(index: point.index, value: total)
        }
    }

    /// Indices of the two largest single-period jumps.
    private var peakIndices: Set<Int> {
        let sorted = increments.sorted { $0.value > $1.value }
        return Set(sorted.prefix(2).map(\.index))
    }

    var body: some View {
        Chart {
            ForEach(cumulative) { point in
                AreaMark(x: .value("i", point.index), y: .value("total", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.3), accent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                LineMark(x: .value("i", point.index), y: .value("total", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(accent)
                    .lineStyle(.init(lineWidth: 2))
            }
            ForEach(cumulative.filter { peakIndices.contains($0.index) }) { point in
                PointMark(x: .value("i", point.index), y: .value("total", point.value))
                    .foregroundStyle(accent)
                    .symbolSize(48)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}
