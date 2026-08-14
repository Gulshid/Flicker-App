import SwiftUI

// Shared View helpers go here as the app grows.
// Example: a reusable "disabled while loading" modifier used across Auth/Onboarding forms.
extension View {
    func disabledWhileLoading(_ isLoading: Bool) -> some View {
        self
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)
    }
}
