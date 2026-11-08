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

#if os(iOS)
// MARK: - Wide layouts

/// Two independently scrolling grouped lists side by side, for wide iOS layouts
/// (iPad, iPhone Duo inner display). Equal columns split cleanly at the Duo's fold.
/// The iOS counterpart of the two-`Form` column layouts the macOS views use.
struct WideColumns<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            List { leading }
                .frame(maxWidth: .infinity)
            List { trailing }
                .frame(maxWidth: .infinity)
        }
        .listStyle(.insetGrouped)
    }
}
#endif

// MARK: - List + detail

/// A list column beside the selected item's detail, for the Horses and Clients
/// tabs when there's room (iPad, iPhone Duo inner display in landscape, Mac).
///
/// It lives inside the tab's `NavigationStack` rather than replacing it with a
/// `NavigationSplitView`, so router deep links and links inside the detail still
/// push onto the same stack.
struct ListDetailSplit<ListColumn: View, Detail: View>: View {
    private let listColumn: ListColumn
    private let detail: Detail
    /// Measured here and clamped, so resizing a window only redraws when the
    /// list column's width actually changes, not on every point of drag (#32).
    @State private var listWidth: CGFloat = 300

    /// The narrowest width at which the split is worth showing.
    static var minimumWidth: CGFloat { 760 }

    init(@ViewBuilder list: () -> ListColumn, @ViewBuilder detail: () -> Detail) {
        self.listColumn = list()
        self.detail = detail()
    }

    static func listWidth(forTotal width: CGFloat) -> CGFloat { min(400, max(300, width * 0.36)) }

    var body: some View {
        HStack(spacing: 0) {
            listColumn
                .frame(width: listWidth)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { Self.listWidth(forTotal: $0.size.width) } action: { listWidth = $0 }
    }
}

extension View {
    /// Sets the navigation title, except when the view is the detail pane of a
    /// `ListDetailSplit`: there the list's title stays in the bar.
    @ViewBuilder
    func detailNavigationTitle(_ title: String, isEmbedded: Bool) -> some View {
        if isEmbedded {
            self
        } else {
            navigationTitle(title).inlineNavTitle()
        }
    }
}

/// The top of an embedded detail pane: the item's name, standing in for the
/// navigation title the pane doesn't set, and the actions on that item. Keeping
/// Edit and Delete here, rather than in the bar beside the list's own actions,
/// makes it clear what they act on.
struct DetailPaneHeader: View {
    let title: String
    var subtitle: String = ""
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)
                .tint(.barnGreen)
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help(Text("Delete"))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
        }
    }
}
