import Foundation

/// Simple protocol-based dependency container.
/// Keeps Firebase/Cloudinary concrete types out of Views and ViewModels,
/// so services can be swapped for mocks in unit tests.
final class DIContainer {
    static let shared = DIContainer()

    lazy var authService: AuthServiceProtocol = FirebaseAuthService()
    lazy var firestoreService: FirestoreServiceProtocol = FirestoreService()
    lazy var mediaService: MediaServiceProtocol = CloudinaryService()

    private init() {}
}
