import SwiftUI

// Variant V22 — "Terminal"
// Hacker/CLI aesthetic: monospaced phosphor-green text, a blinking block caret,
// faint scanlines + grid, and a $-prompt status line. The transcript reads like a
// live terminal session — committed text is solid phosphor, the in-progress tail
// dims like an unconfirmed keystroke, and the prompt animates with the mic level.
//
// Satisfies the standard widget contract: renders committed/partial transcript,
// reflects RecordingState, and degrades gracefully (no text → compact prompt only).
struct Variant22View: View {
    let context: WidgetVariantContext

    // Phosphor palette (terminal green). Pulled from the app's Status.positive token
    // so the accent stays in-theme rather than a random hardcoded green.
    private var phosphor: Color { AppTheme.Status.positive }
    private let fontSize: CGFloat = 13

    private let collapsedWidth: CGFloat = 200
    private let expandedWidth: CGFloat = 320
    private let cornerRadius: CGFloat = 8

    private var width: CGFloat { context.hasText ? expandedWidth : collapsedWidth }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Rectangle()
                .fill(phosphor.opacity(0.18))
                .frame(height: 0.5)

            if context.hasText {
                transcriptArea
                Rectangle()
                    .fill(phosphor.opacity(0.12))
                    .frame(height: 0.5)
            }

            promptLine
        }
        .frame(width: width)
        .background(terminalBackground)
        .overlay(scanlines)
        .overlay(grid)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(phosphor.opacity(0.35), lineWidth: 0.75)
        )
        .shadow(color: phosphor.opacity(0.25), radius: 14, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 6)
        // Second Escape: the whole session fades out like a closed shell.
        .opacity(context.isCanceling ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: context.isCanceling)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: context.hasText)
    }

    // MARK: - Title bar

    // Fake macOS traffic-lights rendered as terminal-style hollow squares, plus a
    // session label that flips to a cancel warning on first Escape.
    private var titleBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(phosphor.opacity(0.45), lineWidth: 0.75)
                    .frame(width: 7, height: 7)
            }

            Spacer(minLength: 8)

            Text(titleText)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(context.isCancelConfirming ? AppTheme.Status.warningStrong : phosphor.opacity(0.55))
                .lineLimit(1)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
    }

    private var titleText: String {
        if context.isCancelConfirming { return "ESC AGAIN ⇒ ^C" }
        switch context.recordingState {
        case .recording:    return "rec — whisper.sh"
        case .transcribing: return "decoding…"
        case .enhancing:    return "polishing…"
        case .starting, .busy: return "init…"
        case .idle:         return "whisper.sh"
        }
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                TerminalTranscriptText(
                    committed: context.committed,
                    partial: context.partial,
                    phosphor: phosphor,
                    fontSize: fontSize,
                    isLive: context.isRecording,
                    isDimming: context.isCancelConfirming || context.isCanceling
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .id("bottom")
            }
            .frame(maxHeight: 150)
            .fixedSize(horizontal: false, vertical: true)
            .mask(topFadeMask)
            .onChange(of: context.committed) { _, _ in scrollDown(proxy) }
            .onChange(of: context.partial) { _, _ in scrollDown(proxy) }
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private var topFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Prompt line

    // The "$ " prompt: a level meter that grows from the live audio average, a status
    // word, and a blinking block caret — the CLI's resting cursor.
    private var promptLine: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                .foregroundColor(phosphor)

            if context.isRecording {
                TerminalLevelMeter(audioMeter: context.audioMeter, phosphor: phosphor)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(promptWord)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(phosphor.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            BlinkingCaret(phosphor: phosphor, fontSize: fontSize, steady: !context.isRecording)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private var promptWord: String {
        switch context.recordingState {
        case .transcribing: return "decoding…"
        case .enhancing:    return "enhancing…"
        case .starting, .busy: return "booting…"
        case .idle, .recording:
            return context.hasText ? "_" : "ready"
        }
    }

    // MARK: - Surfaces

    private var terminalBackground: some View {
        // Near-black CRT screen with a faint green vignette glow from the bottom.
        Color.black
            .overlay(
                RadialGradient(
                    colors: [phosphor.opacity(0.06), Color.clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 220
                )
            )
    }

    // Horizontal CRT scanlines drawn as a repeating gradient over the whole panel.
    private var scanlines: some View {
        GeometryReader { geo in
            let lineHeight: CGFloat = 3
            let count = Int(geo.size.height / lineHeight) + 1
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black.opacity(i % 2 == 0 ? 0.0 : 0.16))
                        .frame(height: lineHeight)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // Very faint vertical grid lines for a terminal-grid feel.
    private var grid: some View {
        GeometryReader { geo in
            let step: CGFloat = 22
            let count = Int(geo.size.width / step)
            ZStack(alignment: .leading) {
                ForEach(1..<max(count, 1), id: \.self) { i in
                    Rectangle()
                        .fill(phosphor.opacity(0.04))
                        .frame(width: 0.5)
                        .offset(x: CGFloat(i) * step)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Terminal transcript text

/// Monospaced transcript: committed = solid phosphor, partial tail dimmed (an
/// unconfirmed keystroke). A trailing block caret marks the live insertion point.
private struct TerminalTranscriptText: View {
    let committed: String
    let partial: String
    let phosphor: Color
    let fontSize: CGFloat
    let isLive: Bool
    let isDimming: Bool

    var body: some View {
        let line = Text(committed).foregroundColor(phosphor)
            + Text(partial).foregroundColor(phosphor.opacity(0.45))

        line
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .lineSpacing(3)
            .tracking(0.3)
            .opacity(isDimming ? 0.35 : 1)
            .blur(radius: isDimming ? 1.5 : 0)
            .animation(.easeOut(duration: 0.25), value: isDimming)
    }
}

// MARK: - Blinking caret

/// A classic blinking block caret. When the session is idle it blinks; while
/// actively recording the prompt meter carries the motion, so the caret holds steady.
private struct BlinkingCaret: View {
    let phosphor: Color
    let fontSize: CGFloat
    var steady: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 4.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let on = steady ? true : (Int(t * 2) % 2 == 0)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(phosphor)
                .frame(width: fontSize * 0.55, height: fontSize)
                .opacity(on ? 0.95 : 0.0)
        }
    }
}

// MARK: - Terminal level meter

/// ASCII-style live level bar driven by the audio average. Fills a row of monospace
/// blocks proportional to the current mic level — the CLI equivalent of a waveform.
private struct TerminalLevelMeter: View {
    let audioMeter: AudioMeter
    let phosphor: Color

    private let cellCount = 14

    // averagePower is roughly 0…1; clamp and lightly boost so quiet speech still moves.
    private var level: Double {
        min(1, max(0, audioMeter.averagePower * 1.4))
    }

    var body: some View {
        let filled = Int((level * Double(cellCount)).rounded())
        HStack(spacing: 2) {
            ForEach(0..<cellCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(phosphor.opacity(i < filled ? 0.9 : 0.14))
                    .frame(width: 5, height: i < filled ? 12 : 5)
            }
        }
        .animation(.easeOut(duration: 0.08), value: filled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
