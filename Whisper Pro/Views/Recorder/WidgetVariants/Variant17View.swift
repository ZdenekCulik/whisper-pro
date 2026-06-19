import SwiftUI

// Variant V17 — "Glass Orb"
// A circular glassmorphic orb that breathes/pulses with the live audio level.
// Heavy ultraThinMaterial, a soft accent glow that swells on sound, and the
// transcript rendered as a caption pill beneath the orb (committed = solid white,
// in-progress tail = dimmed). Reflects every recording state and degrades
// gracefully: idle breathes slowly, recording pulses with audio, transcribing /
// enhancing shows a spinner inside the orb, and Escape dissolves the whole thing.
struct Variant17View: View {
    let context: WidgetVariantContext

    private let orbSize: CGFloat = 84
    private let captionWidth: CGFloat = 300

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let pulse = pulse(at: timeline.date)
            VStack(spacing: 14) {
                orb(pulse: pulse)
                if context.hasText {
                    caption
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: captionWidth)
            // Room around the orb so the blurred glow isn't clipped by the panel edge.
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .opacity(context.isCanceling ? 0 : 1)
            .scaleEffect(context.isCanceling ? 0.86 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: context.hasText)
            .animation(.easeOut(duration: 0.45), value: context.isCanceling)
        }
    }

    // MARK: - Pulse

    /// 0…1 drive for the orb. Always has a slow idle breath; live audio pushes it
    /// far higher so the orb visibly swells while you speak.
    private func pulse(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let breath = (sin(t * 1.5) * 0.5 + 0.5) * 0.28
        guard context.isRecording else { return breath }
        let level = max(context.audioMeter.averagePower, context.audioMeter.peakPower)
        let amplitude = max(0, min(1, pow(level, 0.7)))
        return min(1, breath + amplitude * 0.85)
    }

    // MARK: - Orb

    @ViewBuilder
    private func orb(pulse: Double) -> some View {
        let glowRadius = CGFloat(14 + pulse * 26)        // 14…40 pt
        let glowOpacity = 0.30 + pulse * 0.45            // 0.30…0.75
        let scale = 1 + CGFloat(pulse) * 0.12            // gentle breathe

        ZStack {
            // ── Soft accent glow halo behind the glass ──
            Circle()
                .fill(AppTheme.Accent.primary)
                .frame(width: orbSize, height: orbSize)
                .blur(radius: glowRadius)
                .opacity(context.isRecording ? glowOpacity : glowOpacity * 0.6)
                .scaleEffect(scale)

            // ── Glass body: heavy ultraThinMaterial ──
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    // Top-edge sheen so the glass reads as a lit sphere.
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(scale)
                .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)

            // ── A thin accent ring that brightens with sound ──
            Circle()
                .strokeBorder(AppTheme.Accent.primary.opacity(0.35 + pulse * 0.5), lineWidth: 1.4)
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(scale)

            // ── State content inside the orb ──
            orbContent
                .frame(width: orbSize, height: orbSize)
        }
    }

    @ViewBuilder
    private var orbContent: some View {
        switch context.recordingState {
        case .recording:
            // Live mic bars sitting inside the glass.
            AudioVisualizer(audioMeter: context.audioMeter, color: .white, isActive: true)
                .frame(height: 32)
        case .transcribing:
            ProcessingStatusDisplay(mode: .transcribing, color: .white)
                .scaleEffect(0.85)
        case .enhancing:
            ProcessingStatusDisplay(mode: .enhancing, color: .white)
                .scaleEffect(0.85)
        case .idle, .starting, .busy:
            // Calm resting glyph — a small mic so the orb isn't empty before sound.
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    // MARK: - Caption

    /// Transcript as a floating glass caption beneath the orb. Committed text is
    /// solid white; the still-revising tail is dimmed, matching LiveTranscriptView.
    private var caption: some View {
        captionText
            .font(.system(size: 13, design: ThemeManager.shared.fontDesign))
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .lineLimit(3)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
    }

    private var captionText: Text {
        let committedText = Text(context.committed).foregroundColor(.white)
        guard !context.partial.isEmpty else { return committedText }
        return committedText + Text(context.partial).foregroundColor(.white.opacity(0.4))
    }
}
