import SwiftUI

/// V21 — "Assistant Card".
///
/// A friendly conversational look: a small persona/avatar bubble sits on the left,
/// the live transcript reads as a chat bubble next to it, all on a soft card with a
/// shadow. Same behaviors as the default variant — committed text fully colored,
/// the still-revising tail dimmed, waveform reflects recording state, and the whole
/// thing degrades gracefully through transcribing / enhancing / idle.
struct Variant21View: View {
    let context: WidgetVariantContext

    private static let fontSize: CGFloat = 13
    private static let cardCorner: CGFloat = 18
    private static let bubbleCorner: CGFloat = 14
    private static let avatarSize: CGFloat = 30

    private var fontDesign: Font.Design { ThemeManager.shared.fontDesign }

    // Hide the avatar/empty card while the cancel dissolve plays so only the chat
    // bubble's Invisible Ink scatter is visible, matching the default cancel flow.
    private var isCanceling: Bool { context.isCancelConfirming || context.isCanceling }

    private var bubbleText: String {
        [context.committed, context.partial].filter { !$0.isEmpty }.joined()
    }

    var body: some View {
        card
            .padding(.bottom, 24) // room so the soft shadow isn't clipped by the panel edge
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .opacity(context.isCanceling ? 0 : 1)
            .animation(.easeOut(duration: 0.3).delay(0.55), value: context.isCanceling)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: context.hasText)
            .animation(.easeInOut(duration: 0.28), value: context.isCancelConfirming)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 11) {
            avatar
            content
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(width: context.hasText ? 320 : 188, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Self.cardCorner, style: .continuous)
            .fill(Color(white: 0.10))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Persona avatar

    /// A soft tinted bubble with a waveform glyph. It "breathes" with the live audio
    /// level while recording and shows a quiet, dimmed face otherwise.
    private var avatar: some View {
        TimelineView(.animation(minimumInterval: 0.033)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let level = max(context.audioMeter.averagePower, context.audioMeter.peakPower)
            let pulse = context.isRecording
                ? CGFloat(max(0, min(1, pow(level, 0.7)))) * 0.14 + CGFloat(sin(t * 2.0) + 1) / 2 * 0.04
                : 0

            ZStack {
                Circle()
                    .fill(AppTheme.Accent.primary.opacity(0.22))
                Circle()
                    .strokeBorder(AppTheme.Accent.primary.opacity(0.45), lineWidth: 1)
                Image(systemName: avatarGlyph)
                    .font(.system(size: 13, weight: .semibold, design: fontDesign))
                    .foregroundColor(.white.opacity(context.isRecording ? 0.95 : 0.7))
            }
            .frame(width: Self.avatarSize, height: Self.avatarSize)
            .scaleEffect(1 + pulse)
        }
        // Keep the avatar pinned to the top of the bubble row.
        .frame(width: Self.avatarSize, height: Self.avatarSize)
    }

    private var avatarGlyph: String {
        switch context.recordingState {
        case .recording:    return "waveform"
        case .transcribing: return "waveform.path"
        case .enhancing:    return "sparkles"
        default:            return "waveform"
        }
    }

    // MARK: - Chat bubble content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            chatBubble
            if !isCanceling {
                statusRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chatBubble: some View {
        if isCanceling {
            cancelBubble
        } else if context.hasText {
            transcriptBubble
        } else {
            placeholderBubble
        }
    }

    private var transcriptBubble: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                styledText
                    .font(.system(size: Self.fontSize, design: fontDesign))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .id("bottom")
            }
            .frame(maxHeight: 92)
            .fixedSize(horizontal: false, vertical: true)
            .background(bubbleSurface)
            .clipShape(chatBubbleShape)
            .onChange(of: context.committed) { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: context.partial) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .transaction { $0.disablesAnimations = true }
    }

    // committed = solid white, partial (unconfirmed tail) = dimmed. Trust the
    // provider's own spacing, so no artificial separator between the two.
    private var styledText: Text {
        let committedText = Text(context.committed).foregroundColor(.white)
        guard !context.partial.isEmpty else { return committedText }
        return committedText + Text(context.partial).foregroundColor(.white.opacity(0.42))
    }

    private var placeholderBubble: some View {
        Text("Listening…")
            .font(.system(size: Self.fontSize, design: fontDesign))
            .foregroundColor(.white.opacity(0.35))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bubbleSurface)
            .clipShape(chatBubbleShape)
    }

    // First Escape: dimmed/blurred text + "Esc again" hint. Second Escape: the text
    // turns to solid Invisible Ink and scatters into dust before the panel fades.
    private var cancelBubble: some View {
        ZStack(alignment: .leading) {
            InvisibleInkText(
                text: bubbleText,
                fontSize: Self.fontSize,
                isDissolving: context.isCanceling
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .blur(radius: context.isCanceling ? 0 : 6)
            .opacity(context.isCanceling ? 1 : 0.4)

            if context.isCancelConfirming {
                (Text("Esc").foregroundColor(.white).fontWeight(.semibold)
                    + Text(" again to cancel").foregroundColor(.white.opacity(0.45)))
                    .font(.system(size: Self.fontSize, design: fontDesign))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bubbleSurface)
        .clipShape(chatBubbleShape)
        .animation(.easeOut(duration: 0.5), value: context.isCanceling)
    }

    private var bubbleSurface: some View {
        Color.white.opacity(0.06)
    }

    // Chat-bubble shape: rounded everywhere except a flat top-left corner pointing
    // back at the avatar, so it reads as "spoken by" the persona.
    private var chatBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 4,
            bottomLeadingRadius: Self.bubbleCorner,
            bottomTrailingRadius: Self.bubbleCorner,
            topTrailingRadius: Self.bubbleCorner,
            style: .continuous
        )
    }

    // MARK: - Status row (label + compact waveform)

    private var statusRow: some View {
        HStack(spacing: 8) {
            Text(statusLabel)
                .font(.system(size: 10.5, weight: .medium, design: fontDesign))
                .foregroundColor(.white.opacity(0.5))

            Spacer(minLength: 4)

            waveform
                .frame(height: 22)
        }
        .padding(.horizontal, 2)
    }

    private var statusLabel: String {
        switch context.recordingState {
        case .idle, .starting: return "Assistant"
        case .recording:       return "Listening"
        case .transcribing:    return "Transcribing"
        case .enhancing:       return "Enhancing"
        case .busy:            return "Working"
        }
    }

    @ViewBuilder
    private var waveform: some View {
        // While live (mic on) show the reactive bars; once the mic stops and we're
        // finalizing, keep a calm static waveform; idle is also static.
        if context.isRecording {
            AudioVisualizer(audioMeter: context.audioMeter, color: .white, isActive: true)
        } else {
            StaticVisualizer(color: .white)
        }
    }
}
