import Foundation

/// Small helper so `String` post/author IDs can be used with `.sheet(item:)`.
/// Shared across Feed, Search, Reels, and Notifications.
struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}
