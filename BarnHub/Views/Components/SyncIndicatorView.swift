import SwiftUI

struct SyncIndicatorView: View {
    @Environment(SyncMonitor.self) private var syncMonitor

    var body: some View {
        Image(systemName: syncMonitor.status.icon)
            .font(.subheadline)
            .foregroundStyle(iconColor)
            .symbolEffect(.pulse, isActive: syncMonitor.status == .syncing)
            .accessibilityLabel(syncMonitor.status.label)
            #if os(macOS)
            .padding(.leading, 4)
            #endif
    }

    private var iconColor: Color {
        switch syncMonitor.status {
        #if os(macOS)
        case .succeeded: .secondary
        case .syncing: .accentColor
        case .failed, .idle, .notAvailable: .secondary.opacity(0.5)
        #else
        case .succeeded: .white.opacity(0.8)
        case .syncing: .white
        case .failed, .idle, .notAvailable: .white.opacity(0.5)
        #endif
        }
    }
}
