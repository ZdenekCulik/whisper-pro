import SwiftUI
import OSLog

enum ViewType: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case stats = "Stats"
    case englishCoach = "English coach"
    case models = "AI Models"
    case history = "History"
    case audio = "Audio"
    case dictionary = "Dictionary"
    case settings = "Settings"
    case license = "Whisper Pro"

    var id: String { rawValue }
}

struct ContentView: View {
    private let logger = Logger(subsystem: "com.prakashjoshipax.whisperpro", category: "ContentView")
    @State private var selectedView: ViewType = .dashboard
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selectedView: $selectedView)

            detailCanvas
        }
        .frame(width: 950)
        .frame(minHeight: 730)
        .background(AppTheme.Surface.canvas.ignoresSafeArea())
        .onAppear {
            logger.notice("ContentView appeared")
        }
        .onDisappear {
            logger.notice("ContentView disappeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            if let destination = notification.userInfo?["destination"] as? String,
               let viewType = ViewType.allCases.first(where: { $0.rawValue == destination }) {
                logger.notice("navigateToDestination received: \(destination, privacy: .public)")
                selectedView = viewType
            }
        }
    }

    /// White floating "canvas" card holding the content, on the calm app background.
    private var detailCanvas: some View {
        detailView(for: selectedView)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Surface.cardSolid)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.Border.canvasCard.opacity(0.45), lineWidth: 0.7)
            )
            .padding(.top, 12)
            .padding(.trailing, 14)
            .padding(.bottom, 14)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .dashboard:
            DashboardView()
        case .stats:
            StatsView()
        case .models:
            ModelManagementView()
        case .history:
            InlineHistoryView()
        case .audio:
            AudioSetupView()
        case .dictionary:
            DictionarySettingsView()
        case .englishCoach:
            EnglishCoachView()
        case .settings:
            SettingsView()
        case .license:
            LicenseManagementView()
        }
    }
}
