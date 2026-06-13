import SwiftUI

struct Variant2View: View {
    let context: WidgetVariantContext

    private static let widthKey = "MiniWidgetVariant2Width"
    private static let minWidth: CGFloat = 240
    private static let maxWidth: CGFloat = 520
    private static let defaultWidth: CGFloat = 360

    @State private var widthOverride: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: widthKey)
        guard saved >= minWidth && saved <= maxWidth else { return defaultWidth }
        return saved
    }()

    @State private var isHoveringHandle = false
    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            pill
                .frame(width: widthOverride)

            dragHandle
                .offset(x: 10, y: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - Pill

    private var pill: some View {
        VStack(spacing: 0) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
                Divider()
                    .background(Color.white.opacity(0.12))
            }

            HStack(spacing: 0) {
                Spacer(minLength: 16)

                RecorderStatusDisplay(
                    currentState: context.recordingState,
                    audioMeter: context.audioMeter
                )
                .frame(height: 40)

                Spacer(minLength: 16)
            }
        }
        .background(
            Color.black
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: context.hasText ? 14 : 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: context.hasText ? 14 : 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 6)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(isHoveringHandle ? 0.55 : 0.22))
            .frame(width: 4, height: 24)
            .padding(.vertical, 8)
            .contentShape(Rectangle().size(CGSize(width: 20, height: 40)))
            .onHover { isHoveringHandle = $0 }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartWidth == 0 { dragStartWidth = widthOverride }
                        let proposed = dragStartWidth + value.translation.width
                        widthOverride = min(Variant2View.maxWidth, max(Variant2View.minWidth, proposed))
                    }
                    .onEnded { _ in
                        dragStartWidth = 0
                        UserDefaults.standard.set(widthOverride, forKey: Variant2View.widthKey)
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isHoveringHandle)
    }
}
