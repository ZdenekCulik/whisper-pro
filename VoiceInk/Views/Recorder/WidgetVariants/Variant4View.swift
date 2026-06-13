import SwiftUI

// Variant V4 — "Clean SVG bars"
// Dark pill panel. 28 thin, fully-rounded bars, symmetric mirror around a
// center line (grow up AND down). Springy motion via TimelineView. Monochrome.
struct Variant4View: View {
    let context: WidgetVariantContext

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
                    .padding(.top, 4)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
            }

            V4BarVisualizer(
                audioMeter: context.audioMeter,
                isActive: context.isRecording
            )
            .frame(height: 56)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .frame(width: context.hasText ? 320 : 220)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: context.hasText ? 16 : 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: context.hasText ? 16 : 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Bar Visualizer

private struct V4BarVisualizer: View {
    let audioMeter: AudioMeter
    let isActive: Bool

    private let barCount = 28
    private let barWidth: CGFloat = 2.5
    private let spacing: CGFloat = 3.5
    // Fixed phase offsets per bar — deterministic, no @State needed
    private let phases: [Double] = {
        (0..<28).map { i in Double(i) * 0.38 + 0.1 }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { tl in
            Canvas { ctx, size in
                let time = tl.date.timeIntervalSince1970
                let midY = size.height / 2
                let amplitude = isActive
                    ? CGFloat(max(0, min(1, pow(audioMeter.averagePower, 0.65))))
                    : 0

                let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
                let startX = (size.width - totalWidth) / 2

                for i in 0..<barCount {
                    let x = startX + CGFloat(i) * (barWidth + spacing)

                    // Per-bar half-height: mix of slow wave + fast ripple
                    let slowWave = sin(time * 3.5 + phases[i]) * 0.5 + 0.5
                    let fastRipple = sin(time * 11.0 + phases[i] * 1.7) * 0.3 + 0.7
                    let combined = slowWave * fastRipple

                    // Center bars taller — bell-curve envelope
                    let center = Double(barCount - 1) / 2.0
                    let dist = abs(Double(i) - center) / center      // 0..1
                    let bellFactor = 1.0 - dist * dist * 0.45

                    let minHalf: CGFloat = 2.0
                    let maxHalf: CGFloat = midY - 4
                    let halfH = minHalf + amplitude * CGFloat(combined * bellFactor) * (maxHalf - minHalf)

                    // Opacity: bright core, slight fade on outer bars when quiet
                    let opacity = isActive
                        ? Double(0.55 + amplitude * 0.45 * bellFactor)
                        : 0.28

                    let rect = CGRect(
                        x: x,
                        y: midY - halfH,
                        width: barWidth,
                        height: halfH * 2
                    )
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    ctx.fill(path, with: .color(.white.opacity(opacity)))
                }
            }
        }
    }
}
