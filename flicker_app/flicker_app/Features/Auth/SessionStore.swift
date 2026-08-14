import FirebaseAuth
import Observation

@Observable
final class SessionStore {
    var isAuthenticated = false
    var userId: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        listen()
    }

    private func listen() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userId = user?.uid
            self?.isAuthenticated = user != nil
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
