import Foundation

extension Array {
    /// Splits into chunks of at most `size` elements. Used to stay under
    /// Firestore's 30-value cap on `whereField(_:in:)` /
    /// `whereField(FieldPath.documentID(), in:)` queries — e.g. batching
    /// "which of these posts did I like" lookups (Phase 6).
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
