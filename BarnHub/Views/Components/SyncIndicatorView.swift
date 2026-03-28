import SwiftUI

struct SyncIndicatorView: View {
    @Environment(SyncMonitor.self) private var syncMonitor
    @State private var rotating = false

    var body: some View {
        Image(systemName: syncMonitor.status.icon)
            .font(.subheadline)
            .foregroundStyle(iconColor)
            .symbolEffect(.pulse, isActive: syncMonitor.status == .syncing)
            .accessibilityLabel(syncMonitor.status.label)
    }

    private var iconColor: Color {
        switch syncMonitor.status {
        case .succeeded: .white.opacity(0.8)
        case .syncing: .white
        case .failed: .red
        case .idle, .notAvailable: .white.opacity(0.5)
        }
    }
}
