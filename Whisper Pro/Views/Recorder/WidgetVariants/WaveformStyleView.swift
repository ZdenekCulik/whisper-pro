import SwiftUI

/// A swappable recorder waveform for the V2 mini recorder. Each style is drawn inside
/// padded bounds so strokes never scrape the top or bottom of the pill.
struct WaveformStyleView: View {
    static let styleNames = ["bars", "dots", "sine line", "signal ribbon"]
    static var styleCount: Int { styleNames.count }

    let style: Int
    let audioMeter: AudioMeter
    let isActive: Bool
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
            Canvas { gc, size in
                draw(&gc, size: size, t: ctx.date.timeIntervalSince1970)
            }
        }
        .frame(width: 132, height: 28)
    }

    private var normalizedStyle: Int {
        min(max(style, 0), Self.styleCount - 1)
    }

    private var level: Double {
        guard isActive else { return 0 }
        let raw = max(0, min(1, max(audioMeter.averagePower, audioMeter.peakPower)))
        let boosted = min(1, pow(raw, 0.45) * 1.35)
        return boosted < 0.035 ? 0 : boosted
    }

    private func amp(_ index: Int, count: Int, t: Double) -> Double {
        let phase = Double(index) * 0.45
        let wave = 0.45 + 0.55 * (sin(t * 7 + phase) * 0.5 + 0.5)
        let centerDist = abs(Double(index) - Double(count) / 2) / Double(count / 2)
        let centerBoost = 1.0 - centerDist * 0.35
        return level * wave * centerBoost
    }

    private func draw(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let motionTime = level > 0 ? t : 0
        switch normalizedStyle {
        case 1:  drawDots(&gc, size: size, t: motionTime)
        case 2:  drawLine(&gc, size: size, t: motionTime)
        case 3:  drawSignalRibbon(&gc, size: size, t: motionTime)
        default: drawBars(&gc, size: size, t: motionTime)
        }
    }

    // MARK: - Styles

    private func safeRect(in size: CGSize, verticalInset: CGFloat = 4) -> CGRect {
        CGRect(
            x: 0,
            y: verticalInset,
            width: size.width,
            height: max(1, size.height - verticalInset * 2)
        )
    }

    private func bars(count: Int, width: CGFloat, spacing: CGFloat, size: CGSize) -> CGFloat {
        let total = CGFloat(count) * width + CGFloat(count - 1) * spacing
        return (size.width - total) / 2
    }

    private func drawBars(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let rect = safeRect(in: size)
        let count = 15
        let w: CGFloat = 3
        let sp: CGFloat = 2
        let minH: CGFloat = 4
        let maxH = rect.height
        var x = bars(count: count, width: w, spacing: sp, size: size)
        for i in 0..<count {
            let h = minH + CGFloat(amp(i, count: count, t: t)) * (maxH - minH)
            let r = CGRect(x: x, y: rect.midY - h / 2, width: w, height: h)
            gc.fill(Path(roundedRect: r, cornerRadius: w / 2), with: .color(color.opacity(0.85)))
            x += w + sp
        }
    }

    private func drawDots(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let rect = safeRect(in: size)
        let count = 15, sp: CGFloat = 7
        var x = (size.width - CGFloat(count - 1) * sp) / 2
        for i in 0..<count {
            let r = min(1.5 + CGFloat(amp(i, count: count, t: t)) * 5, rect.height / 2)
            let dot = CGRect(x: x - r, y: rect.midY - r, width: r * 2, height: r * 2)
            gc.fill(Path(ellipseIn: dot), with: .color(color.opacity(0.9)))
            x += sp
        }
    }

    private func drawLine(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let rect = safeRect(in: size, verticalInset: 5)
        var path = Path()
        let steps = 60
        for s in 0...steps {
            let x = size.width * CGFloat(s) / CGFloat(steps)
            let frac = Double(s) / Double(steps)
            let env = sin(frac * .pi)
            let y = rect.midY + CGFloat(sin(frac * 12 + t * 7) * env * level * (rect.height / 2 - 1))
            if s == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        gc.stroke(path, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func drawSignalRibbon(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let rect = safeRect(in: size, verticalInset: 6)
        let rail = Path { path in
            path.move(to: CGPoint(x: 12, y: rect.midY))
            path.addLine(to: CGPoint(x: size.width - 12, y: rect.midY))
        }
        gc.stroke(rail, with: .color(color.opacity(0.16)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

        var ribbon = Path()
        let steps = 72
        let amplitude = level * max(1, rect.height / 2 - 2.5)
        var sparklePoint = CGPoint(x: size.width / 2, y: rect.midY)
        var sparkleLift: CGFloat = 0

        for s in 0...steps {
            let frac = Double(s) / Double(steps)
            let x = 10 + (size.width - 20) * CGFloat(frac)
            let envelope = pow(sin(frac * .pi), 0.65)
            let primary = sin(frac * .pi * 3.1 + t * 5.2)
            let secondary = sin(frac * .pi * 8.0 - t * 3.4) * 0.28
            let lift = CGFloat((primary + secondary) * envelope) * amplitude
            let y = min(rect.maxY, max(rect.minY, rect.midY + lift))
            let point = CGPoint(x: x, y: y)

            if abs(lift) > abs(sparkleLift) {
                sparkleLift = lift
                sparklePoint = point
            }

            if s == 0 {
                ribbon.move(to: point)
            } else {
                ribbon.addLine(to: point)
            }
        }

        gc.stroke(ribbon, with: .color(color.opacity(0.18)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        gc.stroke(ribbon, with: .color(color.opacity(0.92)), style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))

        guard level > 0 else { return }
        let glow = 2.4 + CGFloat(level) * 1.8
        let sparkleRect = CGRect(x: sparklePoint.x - glow, y: sparklePoint.y - glow, width: glow * 2, height: glow * 2)
        gc.fill(Path(ellipseIn: sparkleRect), with: .color(color.opacity(0.8)))
    }
}
