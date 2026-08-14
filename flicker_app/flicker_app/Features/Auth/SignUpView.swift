import SwiftUI

struct SignUpView: View {
    @State private var vm = AuthViewModel()

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $vm.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password (min. 6 characters)", text: $vm.password)
                .textFieldStyle(.roundedBorder)

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await vm.signUp() }
            } label: {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabledWhileLoading(vm.isLoading)

            AppleSignInButton { result in
                if case .failure(let error) = result {
                    vm.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
