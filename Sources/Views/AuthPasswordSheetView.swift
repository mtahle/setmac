import SwiftUI

struct AuthPasswordSheetView: View {
    let request: AuthRequest
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header — lock icon + context
            VStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 4) {
                    Text("Admin Access Required")
                        .font(.headline)
                    Text("to install \(request.tool)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 22)

            Divider()

            // Password field
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                SecureField("Enter password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                .orange.opacity(isPasswordFocused ? 0.65 : 0.28),
                                lineWidth: 1
                            )
                    )
                    .focused($isPasswordFocused)
                    .onSubmit { submit() }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            Divider()

            // Action buttons
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: submit) {
                    Text("Authenticate")
                        .fontWeight(.semibold)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { isPasswordFocused = true }
    }

    private func submit() {
        let p = password
        password = ""
        onSubmit(p)
    }
}
