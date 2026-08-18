import SwiftUI

struct SignInView: View {
    @Bindable var vm: AuthViewModel

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
                placeholder: "Password",
                text: $vm.password,
                textContentType: .password
            )

            HStack {
                Spacer()
                Button("Forgot password?") {
                    Task { await vm.resetPassword() }
                }
                .font(.footnote.weight(.medium))
            }

            if let error = vm.errorMessage {
                InlineErrorBanner(message: error)
            }

            Button {
                Task { await vm.signIn() }
            } label: {
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabledWhileLoading(vm.isLoading)
            .padding(.top, 4)

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
    SignInView(vm: AuthViewModel())
        .padding()
}
