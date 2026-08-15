import FirebaseAuth
import Observation

@Observable
final class SessionStore {
    var isAuthenticated = false
    var userId: String?

    /// nil = not checked yet, true/false once we've asked Firestore
    /// whether users/{uid} exists. Drives RootView's onboarding routing.
    var hasProfile: Bool?

    /// Cached users/{uid} document for the signed-in user. Added in
    /// Phase 5 so every screen that needs the current user's username/
    /// avatar to denormalize onto a new post, comment, or like (see
    /// CreatePostViewModel, PostDetailViewModel) can read it here
    /// instead of re-fetching it from Firestore each time.
    var currentUser: AppUser?

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
                self.currentUser = nil
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
            currentUser = nil
            return
        }
        do {
            hasProfile = try await firestoreService.userExists(uid)
            if hasProfile == true {
                await refreshCurrentUser()
            }
        } catch {
            // Network hiccup checking profile status — don't get the user
            // stuck; treat as "no profile yet" so onboarding is shown and
            // they can retry from there rather than seeing a blank screen.
            hasProfile = false
        }
    }

    /// Re-fetches and caches the current user's profile doc. Called after
    /// onboarding creates it, and after EditProfileView saves a change,
    /// so the cached copy used by post/comment creation stays in sync
    /// with what's on the profile screen.
    func refreshCurrentUser() async {
        guard let uid = userId else { return }
        currentUser = try? await firestoreService.fetchUser(uid)
    }

    /// Cheap local patch so a bio/avatar edit is reflected immediately
    /// without a round trip — mirrors ProfileViewModel.applyLocalEdit.
    func applyLocalProfileEdit(bio: String? = nil, avatarURL: String? = nil) {
        guard var currentUser else { return }
        if let bio { currentUser.bio = bio }
        if let avatarURL { currentUser.avatarURL = avatarURL }
        self.currentUser = currentUser
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
