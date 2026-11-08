import SwiftUI

struct ConfirmationDialog: View {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var confirmTitle: LocalizedStringKey = "Confirm"
    var confirmRole: ButtonRole? = nil
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPresented {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }

                VStack(spacing: 16) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Divider()

                    HStack(spacing: 16) {
                        Button("Cancel", role: .cancel) {
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)

                        Button(confirmTitle, role: confirmRole) {
                            // Confirm first: callers may clear their pending item
                            // when the dialog closes.
                            onConfirm()
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .tint(confirmRole == .destructive ? .red : nil)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                )
                .padding(.horizontal, 40)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilitySortPriority(1)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

#Preview {
    ConfirmationDialog(
        isPresented: .constant(true),
        title: "Delete Horse",
        message: "Are you sure you want to delete this horse? This action cannot be undone.",
        confirmTitle: "Delete",
        confirmRole: .destructive,
        onConfirm: {}
    )
}
