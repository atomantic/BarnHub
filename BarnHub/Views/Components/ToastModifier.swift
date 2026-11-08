import SwiftUI

@Observable
final class ToastState {
    var isPresented = false
    var message = ""
    var isError = false

    /// Closes the form sheet this toast lives in, when it lives in one. Set by
    /// `.toast(_:)` from the environment (see `FormSheet`).
    @ObservationIgnored var closeFormSheet: (() -> Void)?

    func show(_ message: String, isError: Bool = false) {
        self.message = message
        self.isError = isError
        self.isPresented = true
    }

    @MainActor
    func showAndDismiss(_ message: String, isError: Bool = false, dismiss: DismissAction) {
        show(message, isError: isError)
        Task {
            do {
                try await Task.sleep(for: .seconds(0.5))
            } catch {
                return
            }
            // In a form sheet, close the sheet itself: the form's DismissAction
            // doesn't reliably close it on macOS, which left Save needing Cancel.
            if let closeFormSheet {
                closeFormSheet()
            } else {
                dismiss()
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    var isError: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ToastView(message: message, isError: isError)
                        .padding(.top, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isPresented)
            .task(id: isPresented) {
                guard isPresented else { return }
                try? await Task.sleep(for: .seconds(2))
                if isPresented { isPresented = false }
            }
    }
}

struct ToastStateModifier: ViewModifier {
    @Bindable var state: ToastState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.closeFormSheet) private var closeFormSheet

    func body(content: Content) -> some View {
        content
            .onAppear { state.closeFormSheet = closeFormSheet }
            .overlay(alignment: .top) {
                if state.isPresented {
                    ToastView(message: state.message, isError: state.isError)
                        .padding(.top, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: state.isPresented)
            .task(id: state.isPresented) {
                guard state.isPresented else { return }
                try? await Task.sleep(for: .seconds(2))
                if state.isPresented { state.isPresented = false }
            }
    }
}
