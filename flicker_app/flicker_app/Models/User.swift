import Foundation

/// Mirrors the users/{uid} Firestore document.
/// Read/written directly via Firestore's Codable support
/// (FirestoreService.fetchUser / createUserProfile) as of Phase 3.
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
