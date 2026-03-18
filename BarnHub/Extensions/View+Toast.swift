import SwiftUI

extension View {
    func toast(isPresented: Binding<Bool>, message: String, isError: Bool = false) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, isError: isError))
    }

    func toast(_ state: ToastState) -> some View {
        modifier(ToastStateModifier(state: state))
    }
}
