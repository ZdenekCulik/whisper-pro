import SwiftUI

struct Variant15View: View {
    let context: WidgetVariantContext

    private let barCount = 32
    private let barWidth: CGFloat = 5.5
    private let barSpacing: CGFloat = 2.5
    private let maxBarHeight: CGFloat = 94
    private let baselineHeight: CGFloat = 5

    var body: some View {
        VStack(spacing: 14) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
            }

            TimelineView(.animation) { timeline in
                spectrum(at: timeline.date)
            }
            .frame(height: maxBarHeight)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, context.hasText ? 16 : 20)
        .frame(width: context.hasText ? 320 : 300)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
        .frame(width: 540, height: 430, alignment: .bottom)
    }

    private var spectrumWidth: CGFloat {
        CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
    }

    private var rainbowGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .red, location: 0.00),
                .init(color: .orange, location: 0.18),
                .init(color: .yellow, location: 0.36),
                .init(color: .green, location: 0.54),
                .init(color: .blue, location: 0.75),
                .init(color: Color(red: 0.56, green: 0.0, blue: 1.0), location: 1.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func spectrum(at date: Date) -> some View {
        rainbowGradient
            .frame(width: spectrumWidth, height: maxBarHeight)
            .mask(spectrumMask(at: date))
            .frame(width: spectrumWidth, height: maxBarHeight, alignment: .bottom)
    }

    private func spectrumMask(at date: Date) -> some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeight(for: index, at: date))
            }
        }
        .frame(width: spectrumWidth, height: maxBarHeight, alignment: .bottom)
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        let rawAmplitude = min(max(context.audioMeter.averagePower, 0), 1)
        guard context.isRecording, rawAmplitude >= 0.01 else {
            return baselineHeight
        }

        let amplitude = CGFloat(pow(rawAmplitude, 0.65))
        let position = Double(index) / Double(barCount - 1)
        let midrangeProfile = 0.35 + 0.55 * sin(position * Double.pi)
        let randomTexture = 0.12 + pseudoRandom(index) * 0.24
        let seconds = date.timeIntervalSinceReferenceDate
        let motion = 0.82 + 0.18 * sin(seconds * (2.4 + pseudoRandom(index + 17) * 3.5) + Double(index) * 0.42)
        let factor = min(max((midrangeProfile + randomTexture) * motion, 0.2), 1.25)
        let height = amplitude * maxBarHeight * CGFloat(factor)

        return min(maxBarHeight, max(baselineHeight, height))
    }

    private func pseudoRandom(_ index: Int) -> Double {
        let value = sin(Double(index + 1) * 12.9898) * 43758.5453
        return value - floor(value)
    }
}
