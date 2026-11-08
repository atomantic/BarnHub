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

    /// `.backgroundExtensionEffect()` on iOS / macOS 26+, so a full-bleed background
    /// continues under bars and sidebars; no-op on older systems.
    @ViewBuilder
    func barnBackgroundExtension() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
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

    /// Save/confirm button placement. On iOS 27+ `.topBarPinnedTrailing` keeps it
    /// in the bar instead of letting it collapse into the overflow menu on narrow
    /// bars (iPhone Duo outer display in landscape); `.confirmationAction` elsewhere.
    static var pinnedConfirmation: ToolbarItemPlacement {
#if os(iOS)
        if #available(iOS 27.0, *) {
            return .topBarPinnedTrailing
        }
#endif
        return .confirmationAction
    }
}

// MARK: - Toolbar visibility priority

/// How hard the system should try to keep a toolbar item out of the overflow menu.
enum BarnToolbarPriority {
    case high, low

    @available(iOS 27.0, macOS 26.1, *)
    fileprivate var system: ToolbarItemVisibilityPriority {
        switch self {
        case .high: .high
        case .low: .low
        }
    }
}

extension View {
    /// Adds one toolbar item ranked with `visibilityPriority` on iOS 27 / macOS 26.1+,
    /// and a plain `ToolbarItem` on older systems.
    ///
    /// `ToolbarContentBuilder` has no `buildLimitedAvailability`, so the availability
    /// check has to sit at the view level rather than inside a `.toolbar { }` block.
    @ViewBuilder
    func prioritizedToolbarItem<Content: View>(
        _ priority: BarnToolbarPriority,
        placement: ToolbarItemPlacement,
        isPresent: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if !isPresent {
            self
        } else if #available(iOS 27.0, macOS 26.1, *) {
            toolbar {
                ToolbarItem(placement: placement, content: content)
                    .visibilityPriority(priority.system)
            }
        } else {
            toolbar {
                ToolbarItem(placement: placement, content: content)
            }
        }
    }
}
