import SwiftUI

/// Read-only snapshot of everything a mini-widget variant needs to render.
/// Passing one struct keeps every variant's init identical and stable, so
/// variant files can be authored independently without touching shared code.
struct WidgetVariantContext {
    let committed: String      // stabilized transcript (won't change)
    let partial: String        // still-revising tail
    let audioMeter: AudioMeter // live audio levels for the waveform
    let recordingState: RecordingState
    var isCancelConfirming: Bool = false // first Escape: show confirm overlay
    var isCanceling: Bool = false        // second Escape: play dissolve + close

    var isRecording: Bool { recordingState == .recording }
    var hasText: Bool { !committed.isEmpty || !partial.isEmpty }
}

/// The selectable mini-widget looks. V1–V25. Persisted in UserDefaults.
enum WidgetVariant: Int, CaseIterable, Identifiable {
    case v1 = 1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15
    case v16, v17, v18, v19, v20, v21, v22, v23, v24, v25

    var id: Int { rawValue }
    var label: String { "V\(rawValue)" }

    @MainActor @ViewBuilder
    func makeView(_ context: WidgetVariantContext) -> some View {
        switch self {
        case .v1:  Variant1View(context: context)
        case .v2:  Variant2View(context: context)
        case .v3:  Variant3View(context: context)
        case .v4:  Variant4View(context: context)
        case .v5:  Variant5View(context: context)
        case .v6:  Variant6View(context: context)
        case .v7:  Variant7View(context: context)
        case .v8:  Variant8View(context: context)
        case .v9:  Variant9View(context: context)
        case .v10: Variant10View(context: context)
        case .v11: Variant11View(context: context)
        case .v12: Variant12View(context: context)
        case .v13: Variant13View(context: context)
        case .v14: Variant14View(context: context)
        case .v15: Variant15View(context: context)
        case .v16: Variant16View(context: context)
        case .v17: Variant17View(context: context)
        case .v18: Variant18View(context: context)
        case .v19: Variant19View(context: context)
        case .v20: Variant20View(context: context)
        case .v21: Variant21View(context: context)
        case .v22: Variant22View(context: context)
        case .v23: Variant23View(context: context)
        case .v24: Variant24View(context: context)
        case .v25: Variant25View(context: context)
        }
    }
}

/// Holds the currently selected variant, shared by the widget and the cycle badge.
@MainActor
final class WidgetVariantStore: ObservableObject {
    static let shared = WidgetVariantStore()
    private static let key = "MiniWidgetVariant"

    @Published var variant: WidgetVariant {
        didSet { UserDefaults.standard.set(variant.rawValue, forKey: Self.key) }
    }

    private init() {
        let raw = UserDefaults.standard.integer(forKey: Self.key)
        variant = WidgetVariant(rawValue: raw) ?? .v2
    }

    /// Cycle to the next variant (wraps around). Used by the temporary badge.
    func next() {
        let all = WidgetVariant.allCases
        let idx = all.firstIndex(of: variant) ?? 0
        variant = all[(idx + 1) % all.count]
    }
}

/// Baseline look used by not-yet-implemented variants: mirrors the current widget
/// (dark pill, white waveform, white committed / dimmed partial text).
struct WidgetVariantStub: View {
    let context: WidgetVariantContext
    let name: String

    var body: some View {
        VStack(spacing: 0) {
            if context.hasText {
                LiveTranscriptView(committed: context.committed, partial: context.partial)
                Divider().background(Color.white.opacity(0.15))
            }
            RecorderStatusDisplay(
                currentState: context.recordingState,
                audioMeter: context.audioMeter
            )
            .frame(height: 40)
        }
        .frame(width: context.hasText ? 300 : 184)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: context.hasText ? 14 : 20, style: .continuous))
    }
}
