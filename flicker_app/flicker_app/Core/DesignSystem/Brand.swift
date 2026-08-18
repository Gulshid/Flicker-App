import SwiftUI

/// Central place for Flicker's visual identity. Kept small and additive —
/// existing screens are untouched and keep using system colors/styles;
/// only the new Splash and Auth screens opt into this palette for now.
enum Brand {
    /// Warm coral -> pink -> violet, evoking a "flicker" of light.
    static let coral  = Color(red: 1.00, green: 0.42, blue: 0.35)
    static let pink   = Color(red: 0.95, green: 0.24, blue: 0.53)
    static let violet = Color(red: 0.48, green: 0.24, blue: 0.87)

    static let gradientColors: [Color] = [coral, pink, violet]

    static var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Subtle version used for large backgrounds so text stays readable.
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [pink.opacity(0.12), violet.opacity(0.10), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let cornerRadius: CGFloat = 18
    static let fieldHeight: CGFloat = 52
}

/// The app's logo mark: a rounded gradient square with a flame glyph,
/// used on the splash screen and above the sign in / sign up forms.
struct FlickerMark: View {
    var size: CGFloat = 84

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Brand.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.46, height: size * 0.46)
                    .foregroundStyle(.white)
            )
            .shadow(color: Brand.pink.opacity(0.35), radius: 16, x: 0, y: 10)
    }
}

/// Full-width gradient button, used for the primary Sign In / Create Account actions.
struct GradientButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Brand.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous)
                    .fill(isEnabled ? Brand.gradient : LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Rounded, softly-filled field container with a leading icon, shared by
/// BrandTextField and BrandSecureField so email/password rows line up.
private struct BrandFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: Brand.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

struct BrandTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .textContentType(textContentType)
        }
        .modifier(BrandFieldBackground())
    }
}

struct BrandSecureField: View {
    var icon: String = "lock"
    var placeholder: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(textContentType)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .modifier(BrandFieldBackground())
    }
}

/// Small red-tinted banner for surfacing auth errors, replacing the bare
/// red Text used previously.
struct InlineErrorBanner: View {
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
    }
}
