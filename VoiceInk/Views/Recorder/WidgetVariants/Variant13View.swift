import SwiftUI

struct Variant13View: View {
    let context: WidgetVariantContext

    private var widgetWidth: CGFloat {
        context.hasText ? 340 : 260
    }

    private var widgetHeight: CGFloat {
        context.hasText ? 132 : 76
    }

    private var cornerRadius: CGFloat {
        context.hasText ? 22 : 24
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation) { timeline in
                panel(time: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: widgetWidth, height: widgetHeight)
        }
        .frame(width: 540, height: 430, alignment: .bottom)
    }

    private func panel(time: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack {
            shape
                .fill(Color.black.opacity(0.72))

            shape
                .fill(.ultraThinMaterial)
                .opacity(0.42)

            waveformLayer(time: time)
                .padding(.vertical, context.hasText ? 10 : 6)

            transcriptLayer
        }
        .clipShape(shape)
        .overlay(
            shape
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 14)
    }

    private func waveformLayer(time: Double) -> some View {
        Canvas { graphicsContext, size in
            drawWaveform(in: &graphicsContext, size: size, time: time)
        }
        .allowsHitTesting(false)
    }

    private var transcriptLayer: some View {
        Group {
            if context.hasText {
                transcriptText
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
            } else if context.isRecording {
                Text("Listening...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var transcriptText: Text {
        let committed = Text(context.committed).foregroundColor(.white)
        let partial = Text(context.partial).foregroundColor(Color.white.opacity(0.45))
        return committed + partial
    }

    private func drawWaveform(in graphicsContext: inout GraphicsContext, size: CGSize, time: Double) {
        let power = max(0, min(1, context.audioMeter.averagePower))
        let idleBreath = sin(time * 0.9) * 0.5 + 0.5
        let amplitudeFactor = max(power, 0.10 + idleBreath * 0.10)
        let amplitude = min(size.height * 0.36, 6 + size.height * 0.30 * CGFloat(amplitudeFactor))
        let waveColor = Color(red: 0.29, green: 0.62, blue: 1.0)
        let centerLines: [CGFloat] = [0.32, 0.50, 0.68]
        let opacities: [Double] = [0.12, 0.20, 0.12]

        for index in centerLines.indices {
            var path = Path()
            let centerY = size.height * centerLines[index]
            let lineScale = index == 1 ? CGFloat(1.0) : CGFloat(0.58)
            let phase = Double(index) * 0.85
            let step = max(size.width / 96, 2)
            var x = CGFloat(0)
            var isFirstPoint = true

            while x <= size.width {
                let progress = size.width > 0 ? x / size.width : 0
                let primary = sin(Double(progress) * Double.pi * 2.2 + time * 1.45 + phase)
                let secondary = sin(Double(progress) * Double.pi * 5.4 - time * 0.72 + phase)
                let offset = CGFloat(primary * 0.72 + secondary * 0.28) * amplitude * lineScale
                let point = CGPoint(x: x, y: centerY + offset)

                if isFirstPoint {
                    path.move(to: point)
                    isFirstPoint = false
                } else {
                    path.addLine(to: point)
                }

                x += step
            }

            graphicsContext.stroke(
                path,
                with: .color(waveColor.opacity(opacities[index])),
                style: StrokeStyle(lineWidth: index == 1 ? 2.2 : 1.2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
