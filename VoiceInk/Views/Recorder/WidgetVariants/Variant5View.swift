import SwiftUI

struct Variant5View: View {
    let context: WidgetVariantContext

    @State private var isHovered = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    private var dotColor: Color {
        context.isRecording ? Color(red: 1.0, green: 0.22, blue: 0.22) : Color.white.opacity(0.45)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if isHovered {
                expandedWidget
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            } else {
                compactCapsule
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .frame(width: 540, height: 430, alignment: .bottom)
    }

    // MARK: - Compact Capsule

    private var compactCapsule: some View {
        HStack(spacing: 7) {
            Image(systemName: "mic.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))

            ZStack {
                if context.isRecording {
                    Circle()
                        .fill(dotColor.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                }

                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
                )
        )
        .onAppear { startPulse() }
        .onChange(of: context.isRecording) { startPulse() }
    }

    // MARK: - Expanded Widget

    private var expandedWidget: some View {
        VStack(spacing: 0) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
                    .padding(.top, 4)

                Divider()
                    .background(Color.white.opacity(0.12))
            }

            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))

                AudioVisualizer(
                    audioMeter: context.audioMeter,
                    color: .white,
                    isActive: context.isRecording
                )
                .frame(height: 30)

                ZStack {
                    if context.isRecording {
                        Circle()
                            .fill(dotColor.opacity(0.28))
                            .frame(width: 14, height: 14)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                    }
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: context.hasText ? 300 : 200)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: context.hasText ? 16 : 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: context.hasText ? 16 : 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
        )
    }

    // MARK: - Pulse animation

    private func startPulse() {
        pulseScale = 1.0
        pulseOpacity = 1.0
        guard context.isRecording else { return }
        withAnimation(
            .easeOut(duration: 1.1)
            .repeatForever(autoreverses: false)
        ) {
            pulseScale = 2.4
            pulseOpacity = 0.0
        }
    }
}
