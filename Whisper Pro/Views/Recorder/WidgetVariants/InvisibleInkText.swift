import SwiftUI
import AppKit

/// iMessage-style "Invisible Ink": the text is rendered as a field of tiny shimmering
/// particles (via CAEmitterLayer masked to the glyph shapes — the same technique Apple
/// uses). While idle it shows the solid text with a faint live shimmer over it; when
/// `isDissolving` flips true the solid text fades out and the ink particles burst and
/// scatter so the words visibly turn to dust.
struct InvisibleInkText: NSViewRepresentable {
    let text: String
    var fontSize: CGFloat = 13
    var isDissolving: Bool

    func makeNSView(context: Context) -> InkView {
        let view = InkView()
        view.update(text: text, fontSize: fontSize)
        return view
    }

    func updateNSView(_ view: InkView, context: Context) {
        view.update(text: text, fontSize: fontSize)
        view.setDissolving(isDissolving)
    }
}

final class InkView: NSView {
    private let visibleText = CATextLayer()   // solid readable words
    private let maskText = CATextLayer()       // glyph-shaped mask for the particles
    private let emitter = CAEmitterLayer()
    private let shimmerCell = CAEmitterCell()  // constant faint sparkle while idle
    private let burstCell = CAEmitterCell()    // dispersing dust on dissolve

    private var currentText = ""
    private var currentFontSize: CGFloat = 13
    private var dissolving = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var isFlipped: Bool { true }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        configureTextLayer(visibleText)
        configureTextLayer(maskText)

        // Particles live inside the glyph shapes via the mask copy.
        emitter.emitterShape = .rectangle
        emitter.renderMode = .additive
        emitter.mask = maskText

        let dot = Self.particleImage()

        shimmerCell.contents = dot
        shimmerCell.birthRate = 70
        shimmerCell.lifetime = 1.1
        shimmerCell.lifetimeRange = 0.5
        shimmerCell.velocity = 2
        shimmerCell.velocityRange = 4
        shimmerCell.emissionRange = .pi * 2
        shimmerCell.scale = 0.16
        shimmerCell.scaleRange = 0.1
        shimmerCell.alphaSpeed = -0.9
        shimmerCell.color = NSColor.white.cgColor

        burstCell.contents = dot
        burstCell.birthRate = 0
        burstCell.lifetime = 1.4
        burstCell.lifetimeRange = 0.6
        burstCell.velocity = 26
        burstCell.velocityRange = 22
        burstCell.yAcceleration = -14
        burstCell.emissionRange = .pi * 2
        burstCell.scale = 0.18
        burstCell.scaleRange = 0.12
        burstCell.alphaSpeed = -0.7
        burstCell.color = NSColor.white.cgColor

        emitter.emitterCells = [shimmerCell, burstCell]

        layer?.addSublayer(emitter)
        layer?.addSublayer(visibleText)
    }

    private func configureTextLayer(_ t: CATextLayer) {
        t.contentsScale = 2
        t.alignmentMode = .left
        t.isWrapped = true
        t.truncationMode = .none
        t.foregroundColor = NSColor.white.cgColor
    }

    func update(text: String, fontSize: CGFloat) {
        guard text != currentText || fontSize != currentFontSize else {
            layoutLayers()
            return
        }
        currentText = text
        currentFontSize = fontSize
        let font = NSFont.systemFont(ofSize: fontSize)
        for t in [visibleText, maskText] {
            t.string = text
            t.font = font
            t.fontSize = fontSize
        }
        layoutLayers()
    }

    override func layout() {
        super.layout()
        layoutLayers()
    }

    private func layoutLayers() {
        let b = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visibleText.frame = b
        maskText.frame = b
        emitter.frame = b
        emitter.emitterPosition = CGPoint(x: b.midX, y: b.midY)
        emitter.emitterSize = b.size
        CATransaction.commit()
    }

    func setDissolving(_ flag: Bool) {
        guard flag != dissolving else { return }
        dissolving = flag

        if flag {
            // Fade the solid words out smoothly while a one-shot dust burst scatters.
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.45
            fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            visibleText.add(fade, forKey: "fade")

            // Let the dust fly past the glyph edges as it scatters.
            emitter.mask = nil
            shimmerCell.birthRate = 0
            burstCell.birthRate = 1600
            // Stop spawning new dust shortly after the burst so it can fully disperse.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.burstCell.birthRate = 0
            }
        } else {
            visibleText.removeAnimation(forKey: "fade")
            visibleText.opacity = 1
            emitter.mask = maskText
            shimmerCell.birthRate = 70
            burstCell.birthRate = 0
        }
    }

    /// A soft round white dot used for every particle.
    private static func particleImage() -> CGImage? {
        let size = 12
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let center = CGPoint(x: size / 2, y: size / 2)
        let colors = [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) else { return nil }
        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: CGFloat(size) / 2,
            options: []
        )
        return ctx.makeImage()
    }
}
