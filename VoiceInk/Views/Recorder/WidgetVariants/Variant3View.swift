import SwiftUI

// MARK: - Variant 3 "Siri Blob"

struct Variant3View: View {
    let context: WidgetVariantContext

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
                Divider().background(Color.white.opacity(0.12))
            }

            BlobControlBar(
                audioMeter: context.audioMeter,
                recordingState: context.recordingState
            )
            .frame(height: 40)
        }
        .frame(width: context.hasText ? 300 : 200)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: context.hasText ? 14 : 22, style: .continuous))
    }
}

// MARK: - Control bar with blob centered

private struct BlobControlBar: View {
    let audioMeter: AudioMeter
    let recordingState: RecordingState

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 52)
            Spacer()

            SiriBlobView(audioMeter: audioMeter, recordingState: recordingState)
                .frame(width: 80, height: 28)

            Spacer()
            Spacer().frame(width: 52)
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Siri Blob

private struct SiriBlobView: View {
    let audioMeter: AudioMeter
    let recordingState: RecordingState

    @State private var smoothPower: Double = 0.08

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let breath = sin(now * 1.4) * 0.5 + 0.5

                let targetPower: Double
                switch recordingState {
                case .recording:
                    targetPower = max(0.08, audioMeter.averagePower)
                case .transcribing, .enhancing:
                    targetPower = 0.35 + sin(now * 3.0) * 0.2
                default:
                    targetPower = 0.08 + breath * 0.12
                }

                smoothPower = smoothPower + (targetPower - smoothPower) * 0.18

                let cx = size.width / 2
                let cy = size.height / 2
                let baseR = min(size.width, size.height) * 0.28
                let maxBoost = min(size.width, size.height) * 0.32

                let layers: [(offsetScale: Double, alpha: Double, blur: CGFloat, hue: Double)] = [
                    (1.6, 0.30, 14, 0.62),  // outer glow — blue
                    (1.1, 0.55, 8,  0.78),  // mid — purple
                    (0.7, 0.80, 4,  0.88),  // core — pink
                ]

                for layer in layers {
                    let r = CGFloat(baseR + maxBoost * smoothPower * layer.offsetScale * 0.6)
                    var path = Path()
                    let steps = 64
                    for i in 0...steps {
                        let angle = Double(i) / Double(steps) * .pi * 2
                        let w = sin(angle * 3 + now * 2.1) * 0.08
                             + sin(angle * 5 - now * 1.3) * 0.05
                             + sin(angle * 7 + now * 0.9) * 0.03
                        let rr = Double(r) + w * Double(r) * (smoothPower + 0.3)
                        let px = cx + CGFloat(cos(angle) * rr)
                        let py = cy + CGFloat(sin(angle) * rr)
                        if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                        else      { path.addLine(to: CGPoint(x: px, y: py)) }
                    }
                    path.closeSubpath()

                    let color = Color(hue: layer.hue, saturation: 0.9, brightness: 1.0)
                    ctx.addFilter(.blur(radius: layer.blur))
                    ctx.fill(path, with: .color(color.opacity(layer.alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#if DEBUG
struct Variant3View_Previews: PreviewProvider {
    static var previews: some View {
        let meter = AudioMeter(averagePower: 0, peakPower: 0)
        let ctx = WidgetVariantContext(
            committed: "Hello world this is a test",
            partial: "and more",
            audioMeter: meter,
            recordingState: .recording
        )
        Variant3View(context: ctx)
            .frame(width: 540, height: 430)
            .background(Color.gray.opacity(0.3))
    }
}
#endif
