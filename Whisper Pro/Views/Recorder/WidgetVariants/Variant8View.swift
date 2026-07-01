import SwiftUI

struct Variant8View: View {
    let context: WidgetVariantContext

    private let dotCount = 40
    private let dotSize: CGFloat = 5
    private let spacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let power = context.isRecording ? context.audioMeter.averagePower : 0.0

                HStack(spacing: spacing) {
                    ForEach(0..<dotCount, id: \.self) { index in
                        let phase = Double(index) / Double(dotCount) * .pi * 2
                        let wave = sin(time * 3.5 + phase) * 0.5 + 0.5
                        let intensity = power * wave
                        let size = dotSize * (0.4 + intensity * 1.1)
                        let opacity = 0.18 + intensity * 0.82

                        Circle()
                            .fill(Color.white.opacity(opacity))
                            .frame(width: size, height: size)
                    }
                }
                .frame(height: 28)
                .padding(.horizontal, 16)
            }
            .frame(height: 44)
        }
        .frame(width: context.hasText ? 380 : 400)
        .padding(.vertical, context.hasText ? 0 : 8)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: context.hasText ? 16 : 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: context.hasText ? 16 : 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
