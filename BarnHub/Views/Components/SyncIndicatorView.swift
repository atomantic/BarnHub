import SwiftUI

struct SyncIndicatorView: View {
    @Environment(SyncMonitor.self) private var syncMonitor
    /// White icon for a transparent bar over the green Home header (iOS before 26;
    /// Liquid Glass bars use the system colors instead).
    var onBrandHeader = false

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
        case .succeeded: onBrandHeader ? .white.opacity(0.8) : .secondary
        case .syncing: onBrandHeader ? .white : .accentColor
        case .failed, .idle, .notAvailable: onBrandHeader ? .white.opacity(0.5) : .secondary.opacity(0.5)
        #endif
        }
    }
}
