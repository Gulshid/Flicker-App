import Foundation

/// Mirrors the users/{uid} Firestore document.
/// Fleshed out fully in Phase 3 — included now so Phase 2's
/// onboarding/username-check code has a type to reference.
struct AppUser: Codable, Identifiable {
    var id: String            // Firebase Auth uid
    var username: String
    var usernameLowercase: String
    var bio: String?
    var avatarURL: String?
    var followerCount: Int
    var followingCount: Int
    var postCount: Int
    var createdAt: Date
}
