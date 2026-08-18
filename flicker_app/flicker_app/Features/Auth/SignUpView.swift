import SwiftUI

struct SignUpView: View {
    @Bindable var vm: AuthViewModel
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: 14) {
            BrandTextField(
                icon: "envelope",
                placeholder: "Email",
                text: $vm.email,
                keyboardType: .emailAddress,
                textContentType: .username
            )

            BrandSecureField(
                placeholder: "Password (min. 6 characters)",
                text: $vm.password,
                textContentType: .newPassword
            )

            BrandSecureField(
                placeholder: "Confirm password",
                text: $confirmPassword,
                textContentType: .newPassword
            )

            if let error = vm.errorMessage {
                InlineErrorBanner(message: error)
            }

            Button {
                guard vm.password == confirmPassword else {
                    vm.errorMessage = "Passwords don't match."
                    return
                }
                Task { await vm.signUp() }
            } label: {
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Create Account")
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabledWhileLoading(vm.isLoading)
            .padding(.top, 4)

            Text("By continuing you agree to Flicker's Terms of Service and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)

            dividerRow

            AppleSignInButton { result in
                if case .failure(let error) = result {
                    vm.errorMessage = error.localizedDescription
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SignUpView(vm: AuthViewModel())
        .padding()
}
