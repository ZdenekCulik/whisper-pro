import SwiftUI

struct Variant12View: View {
    let context: WidgetVariantContext

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear

            terminalPanel
                .padding(.bottom, 28)
        }
        .frame(width: 540, height: 430, alignment: .bottom)
    }

    private var terminalPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            transcriptView
                .frame(maxWidth: .infinity, minHeight: context.hasText ? 88 : 24, maxHeight: 128, alignment: .topLeading)

            activityBar
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .frame(width: context.hasText ? 320 : 220)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(panelColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(phosphorGreen.opacity(0.82), lineWidth: 1)
        )
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TimelineView(.periodic(from: Date(), by: 0.5)) { timeline in
                        terminalText(cursorVisible: cursorVisible(at: timeline.date))
                            .font(.system(size: 12, design: .monospaced))
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
            }
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: scrollTrigger) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var activityBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(phosphorGreen.opacity(0.18))

                Rectangle()
                    .fill(phosphorGreen)
                    .frame(width: max(1, geometry.size.width * CGFloat(meterLevel)))
            }
        }
        .frame(height: 2)
    }

    private func terminalText(cursorVisible: Bool) -> Text {
        Text("> ")
            .foregroundColor(phosphorGreen)
        + Text(prompted(context.committed))
            .foregroundColor(phosphorGreen)
        + Text(prompted(context.partial))
            .foregroundColor(phosphorGreen.opacity(0.55))
        + Text("▋")
            .foregroundColor(phosphorGreen.opacity(cursorVisible ? 1 : 0))
    }

    private func cursorVisible(at date: Date) -> Bool {
        Int(date.timeIntervalSinceReferenceDate * 2) % 2 == 0
    }

    private func prompted(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\n> ")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo(bottomID, anchor: .bottom)
    }

    private var meterLevel: Double {
        let power = context.audioMeter.averagePower
        guard power.isFinite else { return 0 }
        return min(max(power, 0), 1)
    }

    private var scrollTrigger: String {
        context.committed + "\u{0}" + context.partial
    }

    private var bottomID: String {
        "terminal-bottom"
    }

    private var panelColor: Color {
        Color(red: 0.015, green: 0.018, blue: 0.016)
    }

    private var phosphorGreen: Color {
        Color(red: 0.2, green: 1.0, blue: 0.4)
    }
}
