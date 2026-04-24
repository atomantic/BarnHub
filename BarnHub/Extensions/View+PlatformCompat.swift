import SwiftUI

// MARK: - Cross-platform wrappers for iOS-only SwiftUI modifiers
// These wrappers apply the real modifier on iOS and are no-ops on macOS,
// avoiding @available(macOS, unavailable) conflicts.

extension View {
    /// `.navigationBarTitleDisplayMode(.inline)` on iOS; no-op on macOS.
    @ViewBuilder
    func inlineNavTitle() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    /// `.keyboardType(.decimalPad)` on iOS; no-op on macOS.
    @ViewBuilder
    func decimalKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.decimalPad)
#else
        self
#endif
    }

    /// `.keyboardType(.emailAddress)` on iOS; no-op on macOS.
    @ViewBuilder
    func emailKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.emailAddress)
#else
        self
#endif
    }

    /// `.keyboardType(.phonePad)` on iOS; no-op on macOS.
    @ViewBuilder
    func phoneKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.phonePad)
#else
        self
#endif
    }

    /// `.manageSubscriptionsSheet` on iOS; no-op on macOS.
    @ViewBuilder
    func barnManageSubscriptionsSheet(isPresented: Binding<Bool>) -> some View {
#if os(iOS)
        self.manageSubscriptionsSheet(isPresented: isPresented)
#else
        self
#endif
    }

}

// MARK: - Toolbar placement wrappers

extension ToolbarItemPlacement {
    /// `.topBarTrailing` on iOS; `.automatic` on macOS.
    static var trailingBar: ToolbarItemPlacement {
#if os(iOS)
        .topBarTrailing
#else
        .automatic
#endif
    }

    /// `.topBarLeading` on iOS; `.cancellationAction` on macOS.
    static var leadingBar: ToolbarItemPlacement {
#if os(iOS)
        .topBarLeading
#else
        .cancellationAction
#endif
    }
}
