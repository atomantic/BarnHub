import SwiftUI

@Observable
final class ToastState {
    var isPresented = false
    var message = ""
    var isError = false

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
                dismiss()
            } catch {}
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    var isError: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ToastView(message: message, isError: isError)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isPresented)
            .task(id: isPresented) {
                guard isPresented else { return }
                do {
                    try await Task.sleep(for: .seconds(2))
                    isPresented = false
                } catch {}
            }
    }
}

struct ToastStateModifier: ViewModifier {
    @Bindable var state: ToastState

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if state.isPresented {
                    ToastView(message: state.message, isError: state.isError)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: state.isPresented)
            .task(id: state.isPresented) {
                guard state.isPresented else { return }
                do {
                    try await Task.sleep(for: .seconds(2))
                    state.isPresented = false
                } catch {}
            }
    }
}
