import SwiftUI

struct DashboardGreeting: View {
    @EnvironmentObject var theme: ThemeManager

    private var firstName: String {
        let full = NSFullUserName()
        let first = full.components(separatedBy: " ").first ?? ""
        return first.isEmpty ? "" : first
    }

    private var title: String {
        firstName.isEmpty ? "Welcome back" : "Welcome back, \(firstName)"
    }

    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(theme.resolvedPrimaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
