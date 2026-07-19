import SwiftUI
import AppKit

struct AppSidebar: View {
    @Binding var selectedView: ViewType

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            sidebarSection(ViewType.primaryItems)
                .padding(.top, 20)

            Spacer(minLength: 16)

            Divider()
                .overlay(AppTheme.Border.canvasCard.opacity(0.35))
                .padding(.horizontal, 18)
                .padding(.bottom, 10)

            sidebarSection(ViewType.secondaryItems)
                .padding(.bottom, 14)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .onAppear {
            ViewType.assertSidebarItemsCoverAllCases()
        }
    }

    // MARK: Header (logo + wordmark)

    private var sidebarHeader: some View {
        Button {
            selectedView = .dashboard
        } label: {
            HStack(spacing: 9) {
                AppLogoMark()
                Text("Whisper Pro")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Text.primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Go to Dashboard")
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding(.horizontal, 18)
    }

    private func sidebarSection(_ items: [ViewType]) -> some View {
        VStack(spacing: 3) {
            ForEach(items) { viewType in
                SidebarItemButton(
                    viewType: viewType,
                    isSelected: selectedView == viewType
                ) {
                    selectedView = viewType
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

/// Small rounded app icon used as the sidebar logo.
private struct AppLogoMark: View {
    var body: some View {
        Group {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.Accent.primary)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private extension ViewType {
    var title: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var accessibilityTitle: String {
        rawValue
    }

    static let primaryItems: [ViewType] = [
        .dashboard,
        .stats,
        .history,
        .dictionary,
        .englishCoach,
        .models,
        .audio
    ]

    static let secondaryItems: [ViewType] = [
        .settings,
        .license
    ]

    static func assertSidebarItemsCoverAllCases() {
        #if DEBUG
        let sidebarItems = primaryItems + secondaryItems
        assert(Set(sidebarItems) == Set(allCases) && sidebarItems.count == allCases.count)
        #endif
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .stats: return "chart.bar.xaxis"
        case .englishCoach: return "graduationcap.fill"
        case .history: return "doc.text.fill"
        case .models: return "cpu"
        case .audio: return "mic.fill"
        case .dictionary: return "text.book.closed.fill"
        case .settings: return "gearshape.fill"
        case .license: return "checkmark.seal.fill"
        }
    }

    var sidebarIconStyle: SidebarIconStyle {
        switch self {
        case .dashboard:
            return .init(background: AppTheme.Sidebar.dashboard)
        case .stats:
            return .init(background: AppTheme.Sidebar.dictionary)
        case .englishCoach:
            return .init(background: AppTheme.Sidebar.license)
        case .models:
            return .init(background: AppTheme.Sidebar.models)
        case .audio:
            return .init(background: AppTheme.Sidebar.fallback)
        case .dictionary:
            return .init(background: AppTheme.Sidebar.dictionary)
        case .history:
            return .init(background: AppTheme.Sidebar.audio)
        case .settings:
            return .init(background: AppTheme.Sidebar.fallback)
        case .license:
            return .init(background: AppTheme.Sidebar.license)
        }
    }
}

private struct SidebarIconStyle {
    let background: Color
    var foreground: Color = .white
}

private struct SidebarItemButton: View {
    let viewType: ViewType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                SidebarIconTile(
                    systemName: viewType.icon,
                    style: viewType.sidebarIconStyle
                )

                Text(viewType.title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? selectedForegroundColor : AppTheme.Text.primary)
            .padding(.horizontal, 8)
            .frame(height: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(viewType.accessibilityTitle)
            .accessibilityIdentifier(viewType.accessibilityTitle)
        }
        .buttonStyle(.plain)
        .help(viewType.accessibilityTitle)
        .accessibilityRepresentation {
            Button(viewType.accessibilityTitle, action: action)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(rowBackgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(rowBorderColor, lineWidth: 1)
            }
    }

    private var rowBackgroundColor: Color {
        isSelected ? Color.primary.opacity(0.10) : .clear
    }

    private var rowBorderColor: Color {
        isSelected ? Color.primary.opacity(0.10) : .clear
    }

    private var selectedForegroundColor: Color {
        AppTheme.Text.primary
    }
}

private struct SidebarIconTile: View {
    let systemName: String
    let style: SidebarIconStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(style.background)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 11)
                        .blendMode(.screen)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 1.2, y: 1)

            Image(systemName: systemName)
                .font(.system(size: 14.5, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(style.foreground)
                .shadow(color: Color.black.opacity(0.16), radius: 0.5, y: 0.5)
        }
        .frame(width: 24, height: 24)
    }
}
