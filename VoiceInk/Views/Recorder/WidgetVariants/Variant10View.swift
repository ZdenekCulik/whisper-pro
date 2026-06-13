import SwiftUI

struct Variant10View: View {
    let context: WidgetVariantContext

    // Gradient stops for the pill border stroke and glow
    private let strokeColors: [Color] = [
        Color(red: 0.18, green: 0.55, blue: 1.00),   // blue
        Color(red: 0.15, green: 0.85, blue: 0.85),   // teal
        Color(red: 0.72, green: 0.35, blue: 1.00),   // purple
        Color(red: 0.18, green: 0.55, blue: 1.00),   // blue (loop close)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let power = context.audioMeter.averagePower
            let t = timeline.date.timeIntervalSince1970
            // Slow idle breath 0…0.3, boosted by audio 0…0.7
            let breathe = (sin(t * 1.6) * 0.5 + 0.5) * 0.3
            let audioPulse = Double(power) * 0.7
            let glowIntensity = breathe + audioPulse

            pillContent(glowIntensity: glowIntensity)
        }
        .frame(width: 300, height: context.hasText ? 104 : 56)
    }

    @ViewBuilder
    private func pillContent(glowIntensity: Double) -> some View {
        let glowRadius = CGFloat(16 + glowIntensity * 22)   // 16…38 pt
        let glowOpacity = 0.35 + glowIntensity * 0.50       // 0.35…0.85

        ZStack {
            // ── Outer glow: two blurred gradient capsules behind the pill ──
            Capsule()
                .fill(
                    LinearGradient(
                        colors: strokeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: glowRadius * 0.9)
                .opacity(glowOpacity * 0.55)
                .padding(-CGFloat(glowRadius * 0.6))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: strokeColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: glowRadius * 0.45)
                .opacity(glowOpacity * 0.70)
                .padding(-CGFloat(glowRadius * 0.25))

            // ── Dark glass interior ──
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.08, opacity: 0.96),
                            Color(white: 0.05, opacity: 0.98),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // ── Multi-color gradient stroke ──
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: strokeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .opacity(0.80 + glowIntensity * 0.20)

            // ── Subtle inner top-edge shimmer ──
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.03),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )

            // ── Content ──
            VStack(spacing: 0) {
                if context.hasText {
                    LiveTranscriptView(committed: context.committed, partial: context.partial)

                    // Thin separator between transcript and waveform
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.12),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                }

                // Waveform row
                AudioVisualizer(
                    audioMeter: context.audioMeter,
                    color: .white,
                    isActive: context.isRecording
                )
                .frame(height: 40)
                .padding(.horizontal, 20)
            }
        }
    }
}
