import SwiftUI

// Variant V18 — "Spotlight Bar"
// A wide Raycast/Spotlight-style command bar: a leading mic glyph in a soft chip,
// large single-line live text running across the middle, and a subtle trailing
// hint (live waveform / processing dots / "esc" prompt). One crisp horizontal
// row, productivity-tool aesthetic — distinct from the stacked-pill variants.
struct Variant18View: View {
    let context: WidgetVariantContext

    private static let barHeight: CGFloat = 52
    private static let idleWidth: CGFloat = 360
    private static let activeWidth: CGFloat = 600
    private static let cornerRadius: CGFloat = 16
    private static let fontSize: CGFloat = 16

    private var isCanceling: Bool { context.isCancelConfirming || context.isCanceling }

    var body: some View {
        bar
            .frame(width: context.hasText ? Self.activeWidth : Self.idleWidth)
            .frame(height: Self.barHeight)
            .background(barBackground)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 10)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            // Second Escape: fade the whole bar away after the dissolve plays.
            .opacity(context.isCanceling ? 0 : 1)
            .animation(.easeOut(duration: 0.3).delay(0.5), value: context.isCanceling)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: context.hasText)
    }

    // MARK: - Bar contents

    private var bar: some View {
        HStack(spacing: 12) {
            leadingGlyph

            ZStack {
                if isCanceling {
                    cancelContent.transition(.opacity)
                } else {
                    transcriptContent.transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.25), value: context.isCancelConfirming)

            trailingHint
        }
        .padding(.horizontal, 14)
    }

    // Leading mic chip: rounded square that glows brighter while live, and pulses
    // gently with the audio level so the user can see the bar is "hearing" them.
    private var leadingGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(chipFill)

            Image(systemName: chipIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(chipForeground)
        }
        .frame(width: 32, height: 32)
        .scaleEffect(chipScale)
        .animation(.easeOut(duration: 0.12), value: chipScale)
        .animation(.easeInOut(duration: 0.25), value: context.recordingState)
    }

    private var chipIcon: String {
        switch context.recordingState {
        case .transcribing, .enhancing: return "waveform"
        default: return "mic.fill"
        }
    }

    private var chipFill: Color {
        if context.isRecording {
            return AppTheme.Status.error.opacity(0.18)
        }
        return Color.white.opacity(0.08)
    }

    private var chipForeground: Color {
        if context.isRecording {
            return AppTheme.Status.error.opacity(0.95)
        }
        return Color.white.opacity(0.85)
    }

    // Subtle breath driven by the live level — never larger than ~6% so it stays calm.
    private var chipScale: CGFloat {
        guard context.isRecording else { return 1 }
        let level = max(context.audioMeter.averagePower, context.audioMeter.peakPower)
        let amplitude = max(0, min(1, pow(level, 0.7)))
        return 1 + CGFloat(amplitude) * 0.06
    }

    // MARK: - Transcript (single-line, head-truncated so the newest words stay visible)

    @ViewBuilder
    private var transcriptContent: some View {
        if context.hasText {
            spotlightText
                .font(.system(size: Self.fontSize, weight: .regular, design: ThemeManager.shared.fontDesign))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(placeholder)
                .font(.system(size: Self.fontSize, weight: .regular, design: ThemeManager.shared.fontDesign))
                .foregroundColor(.white.opacity(0.35))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // committed = solid white, partial (still-revising tail) = dimmed. No artificial
    // separator: the provider already embeds spacing between committed and tail.
    private var spotlightText: Text {
        let committedText = Text(context.committed).foregroundColor(.white)
        guard !context.partial.isEmpty else { return committedText }
        return committedText + Text(context.partial).foregroundColor(.white.opacity(0.4))
    }

    private var placeholder: String {
        switch context.recordingState {
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .enhancing: return "Enhancing…"
        default: return "Speak to dictate"
        }
    }

    // MARK: - Trailing hint (waveform / status / esc prompt)

    @ViewBuilder
    private var trailingHint: some View {
        if isCanceling {
            EmptyView()
        } else if context.recordingState == .transcribing || context.recordingState == .enhancing {
            ProcessingStatusDisplay(
                mode: context.recordingState == .enhancing ? .enhancing : .transcribing,
                color: .white
            )
            .fixedSize()
        } else if context.isRecording {
            HStack(spacing: 10) {
                AudioVisualizer(audioMeter: context.audioMeter, color: .white, isActive: true)
                    .frame(width: 56, height: 24)
                    .clipped()
                escHint
            }
        } else {
            StaticVisualizer(color: .white)
                .frame(width: 56)
        }
    }

    // Tiny "esc" key cap so the productivity-tool feel reads like a real command bar.
    private var escHint: some View {
        Text("esc")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
            )
    }

    // MARK: - Escape-to-cancel

    private var cancelText: String {
        [context.committed, context.partial].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var cancelContent: some View {
        ZStack(alignment: .leading) {
            // InvisibleInkText is an NSViewRepresentable that renders/truncates its own
            // text, so SwiftUI .lineLimit/.truncationMode would be no-ops here — match the
            // proven pattern used by the other dissolve variants and just bound the width.
            InvisibleInkText(
                text: cancelText.isEmpty ? placeholder : cancelText,
                fontSize: Self.fontSize,
                isDissolving: context.isCanceling
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .blur(radius: context.isCanceling ? 0 : 6)
            .opacity(context.isCanceling ? 1 : 0.4)

            if context.isCancelConfirming {
                (Text("esc").foregroundColor(.white).fontWeight(.semibold)
                    + Text(" again to cancel").foregroundColor(.white.opacity(0.45)))
                    .font(.system(size: Self.fontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: .black, radius: 12, x: 0, y: 0)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: context.isCanceling)
    }

    // MARK: - Background

    // Solid near-black base with a faint top sheen — crisp, opaque, command-bar feel.
    private var barBackground: some View {
        Color.black
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
