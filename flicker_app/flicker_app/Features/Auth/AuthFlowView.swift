import SwiftUI

struct AuthFlowView: View {
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.2.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.teal)

                Text("Welcome")
                    .font(.largeTitle.bold())

                Text("Sign in to continue, or create an account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if showSignUp {
                    SignUpView()
                } else {
                    SignInView()
                }

                Button {
                    showSignUp.toggle()
                } label: {
                    Text(showSignUp ? "Already have an account? Sign In" : "New here? Create an Account")
                        .font(.footnote)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding()
        }
    }
}
