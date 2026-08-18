import SwiftUI

struct AuthFlowView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    @State private var mode: Mode = .signIn
    // Shared across both modes so switching tabs keeps what's typed
    // and doesn't carry a stale error message from the other form.
    @State private var vm = AuthViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        header

                        modeSwitcher

                        Group {
                            if mode == .signIn {
                                SignInView(vm: vm)
                            } else {
                                SignUpView(vm: vm)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: mode == .signIn ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: mode == .signIn ? .trailing : .leading).combined(with: .opacity)
                        ))
                        .animation(.easeInOut(duration: 0.25), value: mode)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            FlickerMark(size: 64)

            Text(mode == .signIn ? "Welcome back" : "Join Flicker")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(mode == .signIn
                 ? "Sign in to keep up with your feed."
                 : "Create an account to start sharing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { option in
                Button {
                    guard mode != option else { return }
                    vm.errorMessage = nil
                    withAnimation(.easeInOut(duration: 0.25)) {
                        mode = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(mode == option ? .white : .primary)
                        .background(
                            Group {
                                if mode == option {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Brand.gradient)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    AuthFlowView()
}
