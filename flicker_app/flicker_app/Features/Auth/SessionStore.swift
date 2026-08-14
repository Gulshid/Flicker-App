import FirebaseAuth
import Observation

@Observable
final class SessionStore {
    var isAuthenticated = false
    var userId: String?

    /// nil = not checked yet, true/false once we've asked Firestore
    /// whether users/{uid} exists. Drives RootView's onboarding routing.
    var hasProfile: Bool?

    private var handle: AuthStateDidChangeListenerHandle?
    private let firestoreService: FirestoreServiceProtocol

    init(firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService) {
        self.firestoreService = firestoreService
        listen()
    }

    private func listen() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            let uid = user?.uid
            self.userId = uid
            self.isAuthenticated = user != nil

            if uid == nil {
                self.hasProfile = nil
            } else {
                Task { await self.refreshProfileStatus() }
            }
        }
    }

    /// Re-checks whether the current user has a users/{uid} document.
    /// Called once on sign-in, and again by OnboardingFlowView after it
    /// finishes creating one, so RootView can switch over to the main tabs.
    func refreshProfileStatus() async {
        guard let uid = userId else {
            hasProfile = nil
            return
        }
        do {
            hasProfile = try await firestoreService.userExists(uid)
        } catch {
            // Network hiccup checking profile status — don't get the user
            // stuck; treat as "no profile yet" so onboarding is shown and
            // they can retry from there rather than seeing a blank screen.
            hasProfile = false
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
