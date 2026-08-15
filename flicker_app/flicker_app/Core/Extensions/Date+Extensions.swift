import Foundation

// Shared date formatting for feed/comment timestamps.
extension Date {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// "2h ago", "3d ago", etc. — used throughout the feed and comments
    /// instead of an absolute timestamp.
    var relativeTimeString: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }
}
