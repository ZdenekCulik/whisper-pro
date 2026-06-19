import SwiftUI
import Sticker

struct StickerAchievementBadge: View {
    /// When nil, the badge follows the user's global pick (StickerVariantStore).
    private let variantOverride: StickerLightningBoltVariant?
    @ObservedObject private var store = StickerVariantStore.shared
    @EnvironmentObject private var theme: ThemeManager

    init(variant: StickerLightningBoltVariant? = nil) {
        self.variantOverride = variant
    }

    private var variant: StickerLightningBoltVariant { variantOverride ?? store.variant }

    var body: some View {
        lightningBadge
            .aspectRatio(0.78, contentMode: .fit)
            .animation(.snappy) { view in
                view
                    .stickerEffect()
                    .stickerColorIntensity(0.48)
                    .stickerBlend(0.28)
                    .stickerCheckerIntensity(0.8)
                    .stickerNoiseIntensity(0.75)
                    .stickerLightIntensity(0.2)
                    .stickerMotionEffect(.pointerHover(intensity: 0.5))
            }
            .shadow(color: .black.opacity(theme.skin.colorScheme == .dark ? 0.45 : 0.24), radius: 18, x: 10, y: 12)
            .accessibilityLabel("Holographic lightning sticker")
    }

    private var lightningBadge: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outerStroke = side * 0.11
            let innerStroke = side * 0.065
            let inset = side * 0.12

            ZStack {
                StickerLightningBoltShape(variant: variant)
                    .stroke(
                        Color(red: 0.86, green: 0.88, blue: 1.0).opacity(0.96),
                        style: StrokeStyle(lineWidth: outerStroke, lineCap: .round, lineJoin: .round)
                    )

                StickerLightningBoltShape(variant: variant)
                    .fill(Color.white.opacity(0.88))

                StickerLightningBoltShape(variant: variant)
                    .stroke(
                        Color(red: 0.08, green: 0.08, blue: 0.13).opacity(0.9),
                        style: StrokeStyle(lineWidth: innerStroke, lineCap: .round, lineJoin: .round)
                    )
            }
            .padding(inset)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
        }
    }
}

enum StickerLightningBoltVariant: Int, CaseIterable, Identifiable {
    case v1 = 1
    case v2
    case v3
    case v4
    case v5
    case v6   // Bolt (refined)
    case v7   // Star burst
    case v8   // Shield
    case v9   // Hexagon
    case v10  // Faceted gem
    case v11  // Speech bubble
    case v12  // Equalizer
    case v13  // Rocket
    case v14  // Crown
    case v15  // Flame

    var id: Int { rawValue }

    var label: String { "\(rawValue)" }

    var displayName: String {
        switch self {
        case .v1: return "Bolt 1"
        case .v2: return "Bolt 2"
        case .v3: return "Bolt 3"
        case .v4: return "Bolt 4"
        case .v5: return "Bolt 5"
        case .v6: return "Bolt"
        case .v7: return "Star"
        case .v8: return "Shield"
        case .v9: return "Hexagon"
        case .v10: return "Gem"
        case .v11: return "Bubble"
        case .v12: return "Equalizer"
        case .v13: return "Rocket"
        case .v14: return "Crown"
        case .v15: return "Flame"
        }
    }
}

/// Holds the user's chosen sticker badge shape, shared across every badge.
@MainActor
final class StickerVariantStore: ObservableObject {
    static let shared = StickerVariantStore()
    private static let key = "StickerBadgeVariant"

    @Published var variant: StickerLightningBoltVariant {
        didSet { UserDefaults.standard.set(variant.rawValue, forKey: Self.key) }
    }

    private init() {
        let raw = UserDefaults.standard.integer(forKey: Self.key)
        variant = StickerLightningBoltVariant(rawValue: raw) ?? .v5
    }
}

private struct StickerLightningBoltShape: Shape {
    let variant: StickerLightningBoltVariant

    func path(in rect: CGRect) -> Path {
        let points = variant.points

        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: point(first, in: rect))
        for point in points.dropFirst() {
            path.addLine(to: self.point(point, in: rect))
        }
        path.closeSubpath()

        return path
    }

    private func point(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}

private extension StickerLightningBoltVariant {
    var points: [CGPoint] {
        switch self {
        case .v1:
            return [
                CGPoint(x: 0.31, y: 0.11),
                CGPoint(x: 0.70, y: 0.09),
                CGPoint(x: 0.78, y: 0.17),
                CGPoint(x: 0.66, y: 0.43),
                CGPoint(x: 0.88, y: 0.43),
                CGPoint(x: 0.95, y: 0.53),
                CGPoint(x: 0.39, y: 0.91),
                CGPoint(x: 0.29, y: 0.84),
                CGPoint(x: 0.39, y: 0.58),
                CGPoint(x: 0.16, y: 0.58),
                CGPoint(x: 0.09, y: 0.49),
                CGPoint(x: 0.24, y: 0.16)
            ]
        case .v2:
            return [
                CGPoint(x: 0.34, y: 0.10),
                CGPoint(x: 0.72, y: 0.10),
                CGPoint(x: 0.79, y: 0.18),
                CGPoint(x: 0.65, y: 0.44),
                CGPoint(x: 0.87, y: 0.44),
                CGPoint(x: 0.93, y: 0.52),
                CGPoint(x: 0.36, y: 0.92),
                CGPoint(x: 0.28, y: 0.84),
                CGPoint(x: 0.39, y: 0.58),
                CGPoint(x: 0.15, y: 0.58),
                CGPoint(x: 0.09, y: 0.49),
                CGPoint(x: 0.25, y: 0.17)
            ]
        case .v3:
            return [
                CGPoint(x: 0.30, y: 0.13),
                CGPoint(x: 0.68, y: 0.09),
                CGPoint(x: 0.77, y: 0.17),
                CGPoint(x: 0.64, y: 0.42),
                CGPoint(x: 0.89, y: 0.42),
                CGPoint(x: 0.96, y: 0.51),
                CGPoint(x: 0.38, y: 0.90),
                CGPoint(x: 0.27, y: 0.83),
                CGPoint(x: 0.37, y: 0.60),
                CGPoint(x: 0.13, y: 0.60),
                CGPoint(x: 0.07, y: 0.51),
                CGPoint(x: 0.22, y: 0.18)
            ]
        case .v4:
            return [
                CGPoint(x: 0.38, y: 0.10),
                CGPoint(x: 0.73, y: 0.10),
                CGPoint(x: 0.80, y: 0.17),
                CGPoint(x: 0.67, y: 0.45),
                CGPoint(x: 0.91, y: 0.45),
                CGPoint(x: 0.95, y: 0.54),
                CGPoint(x: 0.37, y: 0.91),
                CGPoint(x: 0.30, y: 0.83),
                CGPoint(x: 0.41, y: 0.56),
                CGPoint(x: 0.17, y: 0.56),
                CGPoint(x: 0.11, y: 0.48),
                CGPoint(x: 0.29, y: 0.16)
            ]
        case .v5:
            return [
                CGPoint(x: 0.28, y: 0.12),
                CGPoint(x: 0.66, y: 0.10),
                CGPoint(x: 0.75, y: 0.18),
                CGPoint(x: 0.61, y: 0.43),
                CGPoint(x: 0.86, y: 0.43),
                CGPoint(x: 0.94, y: 0.53),
                CGPoint(x: 0.34, y: 0.91),
                CGPoint(x: 0.25, y: 0.83),
                CGPoint(x: 0.36, y: 0.57),
                CGPoint(x: 0.13, y: 0.57),
                CGPoint(x: 0.07, y: 0.48),
                CGPoint(x: 0.21, y: 0.17)
            ]
        case .v6: // Bolt (refined)
            return [
                CGPoint(x: 0.64, y: 0.06), CGPoint(x: 0.74, y: 0.06),
                CGPoint(x: 0.40, y: 0.45), CGPoint(x: 0.82, y: 0.45),
                CGPoint(x: 0.36, y: 0.94), CGPoint(x: 0.26, y: 0.94),
                CGPoint(x: 0.60, y: 0.55), CGPoint(x: 0.18, y: 0.55)
            ]
        case .v7: // Star burst
            return [
                CGPoint(x: 0.50, y: 0.084), CGPoint(x: 0.608, y: 0.395),
                CGPoint(x: 0.937, y: 0.402), CGPoint(x: 0.675, y: 0.601),
                CGPoint(x: 0.77, y: 0.916), CGPoint(x: 0.50, y: 0.728),
                CGPoint(x: 0.23, y: 0.916), CGPoint(x: 0.325, y: 0.601),
                CGPoint(x: 0.063, y: 0.402), CGPoint(x: 0.392, y: 0.395)
            ]
        case .v8: // Shield
            return [
                CGPoint(x: 0.50, y: 0.10), CGPoint(x: 0.90, y: 0.12),
                CGPoint(x: 0.90, y: 0.30), CGPoint(x: 0.88, y: 0.46),
                CGPoint(x: 0.82, y: 0.62), CGPoint(x: 0.72, y: 0.76),
                CGPoint(x: 0.60, y: 0.87), CGPoint(x: 0.50, y: 0.93),
                CGPoint(x: 0.40, y: 0.87), CGPoint(x: 0.28, y: 0.76),
                CGPoint(x: 0.18, y: 0.62), CGPoint(x: 0.12, y: 0.46),
                CGPoint(x: 0.10, y: 0.30), CGPoint(x: 0.10, y: 0.12)
            ]
        case .v9: // Hexagon
            return [
                CGPoint(x: 0.275, y: 0.111), CGPoint(x: 0.725, y: 0.111),
                CGPoint(x: 0.95, y: 0.50), CGPoint(x: 0.725, y: 0.889),
                CGPoint(x: 0.275, y: 0.889), CGPoint(x: 0.05, y: 0.50)
            ]
        case .v10: // Faceted gem
            return [
                CGPoint(x: 0.36, y: 0.18), CGPoint(x: 0.64, y: 0.18),
                CGPoint(x: 0.82, y: 0.36), CGPoint(x: 0.94, y: 0.36),
                CGPoint(x: 0.50, y: 0.88), CGPoint(x: 0.06, y: 0.36),
                CGPoint(x: 0.18, y: 0.36)
            ]
        case .v11: // Speech bubble
            return [
                CGPoint(x: 0.20, y: 0.10), CGPoint(x: 0.80, y: 0.10),
                CGPoint(x: 0.87, y: 0.13), CGPoint(x: 0.92, y: 0.20),
                CGPoint(x: 0.94, y: 0.28), CGPoint(x: 0.94, y: 0.46),
                CGPoint(x: 0.92, y: 0.54), CGPoint(x: 0.87, y: 0.61),
                CGPoint(x: 0.80, y: 0.64), CGPoint(x: 0.48, y: 0.64),
                CGPoint(x: 0.40, y: 0.90), CGPoint(x: 0.33, y: 0.64),
                CGPoint(x: 0.20, y: 0.64), CGPoint(x: 0.13, y: 0.61),
                CGPoint(x: 0.08, y: 0.54), CGPoint(x: 0.06, y: 0.46),
                CGPoint(x: 0.06, y: 0.28), CGPoint(x: 0.08, y: 0.20),
                CGPoint(x: 0.13, y: 0.13)
            ]
        case .v12: // Equalizer
            return [
                CGPoint(x: 0.06, y: 0.96), CGPoint(x: 0.06, y: 0.40),
                CGPoint(x: 0.19, y: 0.40), CGPoint(x: 0.19, y: 0.84),
                CGPoint(x: 0.2475, y: 0.84), CGPoint(x: 0.2475, y: 0.24),
                CGPoint(x: 0.3775, y: 0.24), CGPoint(x: 0.3775, y: 0.84),
                CGPoint(x: 0.435, y: 0.84), CGPoint(x: 0.435, y: 0.10),
                CGPoint(x: 0.565, y: 0.10), CGPoint(x: 0.565, y: 0.84),
                CGPoint(x: 0.6225, y: 0.84), CGPoint(x: 0.6225, y: 0.24),
                CGPoint(x: 0.7525, y: 0.24), CGPoint(x: 0.7525, y: 0.84),
                CGPoint(x: 0.81, y: 0.84), CGPoint(x: 0.81, y: 0.40),
                CGPoint(x: 0.94, y: 0.40), CGPoint(x: 0.94, y: 0.96)
            ]
        case .v13: // Rocket
            return [
                CGPoint(x: 0.50, y: 0.06), CGPoint(x: 0.585, y: 0.20),
                CGPoint(x: 0.61, y: 0.34), CGPoint(x: 0.61, y: 0.60),
                CGPoint(x: 0.61, y: 0.70), CGPoint(x: 0.78, y: 0.78),
                CGPoint(x: 0.83, y: 0.92), CGPoint(x: 0.66, y: 0.85),
                CGPoint(x: 0.61, y: 0.82), CGPoint(x: 0.585, y: 0.94),
                CGPoint(x: 0.50, y: 0.86), CGPoint(x: 0.415, y: 0.94),
                CGPoint(x: 0.39, y: 0.82), CGPoint(x: 0.34, y: 0.85),
                CGPoint(x: 0.17, y: 0.92), CGPoint(x: 0.22, y: 0.78),
                CGPoint(x: 0.39, y: 0.70), CGPoint(x: 0.39, y: 0.60),
                CGPoint(x: 0.39, y: 0.34), CGPoint(x: 0.415, y: 0.20)
            ]
        case .v14: // Crown
            return [
                CGPoint(x: 0.14, y: 0.80), CGPoint(x: 0.14, y: 0.30),
                CGPoint(x: 0.32, y: 0.55), CGPoint(x: 0.50, y: 0.12),
                CGPoint(x: 0.68, y: 0.55), CGPoint(x: 0.86, y: 0.30),
                CGPoint(x: 0.86, y: 0.80)
            ]
        case .v15: // Flame
            return [
                CGPoint(x: 0.52, y: 0.06), CGPoint(x: 0.60, y: 0.22),
                CGPoint(x: 0.64, y: 0.40), CGPoint(x: 0.78, y: 0.55),
                CGPoint(x: 0.85, y: 0.71), CGPoint(x: 0.80, y: 0.85),
                CGPoint(x: 0.64, y: 0.93), CGPoint(x: 0.50, y: 0.94),
                CGPoint(x: 0.36, y: 0.93), CGPoint(x: 0.20, y: 0.85),
                CGPoint(x: 0.15, y: 0.71), CGPoint(x: 0.24, y: 0.57),
                CGPoint(x: 0.34, y: 0.49), CGPoint(x: 0.30, y: 0.36),
                CGPoint(x: 0.40, y: 0.27), CGPoint(x: 0.43, y: 0.15)
            ]
        }
    }
}

#if DEBUG
#Preview("Sticker Badge") {
    HStack(spacing: 16) {
        ForEach(StickerLightningBoltVariant.allCases) { variant in
            StickerAchievementBadge(variant: variant)
                .environmentObject(ThemeManager())
                .frame(width: 120, height: 150)
        }
    }
    .padding(40)
}
#endif
