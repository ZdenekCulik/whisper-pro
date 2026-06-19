import SwiftUI

/// Debug gallery: every recorder waveform style, live and stacked, so a design can be
/// picked. Each row is shown inside the same black panel the floating recorder uses.
struct WaveformDebugView: View {
    @AppStorage("WaveformStyle") private var selectedStyle: Int = 0

    // A constant "speaking" level so the gallery previews active motion.
    private let meter = AudioMeter(averagePower: 0.7, peakPower: 0.85)

    private var normalizedSelectedStyle: Int {
        min(max(selectedStyle, 0), WaveformStyleView.styleCount - 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Waveform styles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.Text.primary)
                Text("Four recorder waveforms, live. Tap one to make it the active recorder waveform.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Text.secondary)
                    .padding(.bottom, 6)

                ForEach(0..<WaveformStyleView.styleCount, id: \.self) { i in
                    row(i)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            selectedStyle = normalizedSelectedStyle
        }
    }

    private func row(_ i: Int) -> some View {
        let isActive = normalizedSelectedStyle == i
        return Button {
            selectedStyle = i
        } label: {
            HStack(spacing: 16) {
                Text("\(i)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.Text.secondary)
                    .frame(width: 20)

                HStack(spacing: 0) {
                    Spacer(minLength: 16)
                    WaveformStyleView(style: i, audioMeter: meter, isActive: true)
                        .frame(height: 40)
                    Spacer(minLength: 16)
                }
                .frame(width: 300)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isActive ? AppTheme.Accent.primary : Color.white.opacity(0.08),
                                      lineWidth: isActive ? 2 : 0.6)
                )

                Text(WaveformStyleView.styleNames[i])
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? AppTheme.Accent.primary : AppTheme.Text.secondary)

                if isActive {
                    Text("active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(AppTheme.Accent.primary))
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
