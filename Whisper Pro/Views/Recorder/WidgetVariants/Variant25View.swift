import SwiftUI

// Variant V25 — "Status HUD"
// A game-like heads-up display: a circular mic-level meter ring sweeps around a
// center glyph, with an elapsed-time readout and the live transcript carried in a
// status strip beneath. Energetic and precise — the ring reacts to audio in real
// time, the glyph swaps per recording state, and the strip degrades to a compact
// orb when there is no text yet.
struct Variant25View: View {
    let context: WidgetVariantContext

    private let ringSize: CGFloat = 44
    private let cornerRadius: CGFloat = 16
    private let textWidth: CGFloat = 320
    private let compactWidth: CGFloat = 176

    // Accent color is driven by the recording phase so the whole HUD reads at a glance.
    private var accent: Color {
        switch context.recordingState {
        case .recording:               return AppTheme.Status.error
        case .transcribing, .enhancing: return AppTheme.Data.audio
        case .starting, .busy:         return AppTheme.Data.yellow
        case .idle:                    return Color.white.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: context.hasText ? 12 : 10) {
            meterCluster

            if context.hasText {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 36)

                statusStrip
            }
        }
        .padding(.horizontal, context.hasText ? 14 : 12)
        .padding(.vertical, 12)
        .frame(width: context.hasText ? textWidth : compactWidth, alignment: .leading)
        .background(hudBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 6)
        .opacity(context.isCanceling ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: context.isCanceling)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: context.hasText)
        .animation(.easeInOut(duration: 0.25), value: context.recordingState)
    }

    // MARK: - Background

    private var hudBackground: some View {
        Color.black.overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Meter cluster (ring + glyph + elapsed time)

    private var meterCluster: some View {
        VStack(spacing: 5) {
            meterRing
            ElapsedTimeReadout(isRunning: context.isRecording, accent: accent)
        }
    }

    // The live ring: a faint full track with a bright arc that grows with the mic
    // level, plus a soft glow that pulses on loud peaks. The center glyph swaps with
    // the recording state.
    private var meterRing: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let level = meterLevel
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Idle breathing so the ring never looks frozen; audio drives the rest.
            let breathe = (sin(t * 1.8) * 0.5 + 0.5) * 0.12
            let fraction = context.isRecording
                ? max(0.06, min(1.0, level))
                : breathe + 0.06

            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)

                // Active level arc, starting at the top and sweeping clockwise.
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.75), accent],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(context.isRecording ? 0.6 : 0.2),
                            radius: 4 + CGFloat(level) * 6)

                centerGlyph
            }
            .frame(width: ringSize, height: ringSize)
        }
    }

    // Whichever of average/peak is stronger, shaped the same way the waveform does it
    // so the ring matches the bars' responsiveness.
    private var meterLevel: Double {
        let raw = max(context.audioMeter.averagePower, context.audioMeter.peakPower)
        return max(0, min(1, pow(raw, 0.7)))
    }

    @ViewBuilder
    private var centerGlyph: some View {
        switch context.recordingState {
        case .transcribing, .enhancing:
            ProcessingIndicator(color: accent)
        case .recording:
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        case .starting, .busy:
            Image(systemName: "hourglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        case .idle:
            Image(systemName: "mic")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Status strip (state label + transcript)

    private var statusStrip: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                Text(statusLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.55))
            }

            HUDTranscriptText(committed: context.committed, partial: context.partial)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLabel: String {
        switch context.recordingState {
        case .idle:         return "READY"
        case .starting:     return "ARMING"
        case .recording:    return "LIVE"
        case .transcribing: return "DECODING"
        case .enhancing:    return "POLISHING"
        case .busy:         return "BUSY"
        }
    }
}

// MARK: - Elapsed time readout

/// A monospaced-digit mm:ss counter that ticks while recording and resets on stop.
/// Kept tiny so it sits cleanly under the ring as a HUD stat.
private struct ElapsedTimeReadout: View {
    let isRunning: Bool
    let accent: Color

    @State private var startDate: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            Text(displayString(at: timeline.date))
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundColor(isRunning ? accent.opacity(0.9) : .white.opacity(0.35))
        }
        .onChange(of: isRunning) { _, running in
            startDate = running ? Date() : nil
        }
        .onAppear {
            if isRunning { startDate = Date() }
        }
    }

    private func displayString(at date: Date) -> String {
        guard let startDate else { return "0:00" }
        let total = max(0, Int(date.timeIntervalSince(startDate)))
        return String(format: "%01d:%02d", total / 60, total % 60)
    }
}

// MARK: - HUD transcript text

/// committed = solid white, partial (the still-revising tail) = dimmed. Scrolls and
/// stays pinned to the newest line, with a soft top fade so older lines dissolve.
private struct HUDTranscriptText: View {
    let committed: String
    let partial: String

    private var styledText: Text {
        let committedText = Text(committed).foregroundColor(.white)
        guard !partial.isEmpty else { return committedText }
        // Trust the provider's spacing — the live tail can be the rest of a word.
        return committedText + Text(partial).foregroundColor(.white.opacity(0.4))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                styledText
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bottom")
            }
            .frame(height: 40)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.22),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: committed) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: partial) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .transaction { $0.disablesAnimations = true }
    }
}
