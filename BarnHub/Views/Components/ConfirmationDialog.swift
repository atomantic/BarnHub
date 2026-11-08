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

/// Like ConfirmationDialog, but offers a choice of actions stacked vertically, the
/// recommended one first and prominent, plus Cancel. Used where a plain "Delete"
/// would throw away history the user may want to keep.
struct ChoiceDialog: View {
    struct Choice {
        let title: LocalizedStringKey
        var role: ButtonRole? = nil
        /// The recommended choice: drawn prominent and bound to Return.
        var isDefault = false
        let action: () -> Void
    }

    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let choices: [Choice]

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
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    VStack(spacing: 10) {
                        ForEach(choices.indices, id: \.self) { index in
                            choiceButton(choices[index])
                        }
                        Button("Cancel", role: .cancel) {
                            isPresented = false
                        }
                        .keyboardShortcut(.cancelAction)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
                .frame(maxWidth: 440)
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

    @ViewBuilder
    private func choiceButton(_ choice: Choice) -> some View {
        let button = Button(role: choice.role) {
            // Act first: callers may clear their pending item when the dialog closes.
            choice.action()
            isPresented = false
        } label: {
            Text(choice.title)
                .frame(maxWidth: .infinity)
        }
        .tint(choice.role == .destructive ? .red : .barnGreen)
        if choice.isDefault {
            button
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        } else {
            button
                .buttonStyle(.bordered)
        }
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
