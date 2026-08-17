import Foundation
import Observation

/// Drives SearchView: debounced username search plus, when the search
/// field is empty, an Explore grid of the most-liked posts across the
/// whole app. New in Phase 9.
@MainActor
@Observable
final class SearchViewModel {
    var queryText: String = "" {
        didSet {
            guard queryText != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var userResults: [AppUser] = []
    private(set) var isSearching = false

    private(set) var explorePosts: [Post] = []
    private(set) var isLoadingExplore = false
    private var exploreCursor: FeedCursor?
    private var hasMoreExplorePages = true

    var errorMessage: String?

    private var searchTask: Task<Void, Never>?
    private let firestoreService: FirestoreServiceProtocol

    init(firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService) {
        self.firestoreService = firestoreService
    }

    var isSearchActive: Bool {
        !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Debounces every keystroke by 300ms before actually querying
    /// Firestore — typing "alice" one letter at a time shouldn't fire
    /// five separate reads against the free-tier quota.
    private func scheduleSearch() {
        searchTask?.cancel()
        let text = queryText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            userResults = []
            isSearching = false
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            await self.runSearch(text)
        }
    }

    private func runSearch(_ text: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            userResults = try await firestoreService.searchUsers(prefix: text, limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Explore grid

    func loadExploreIfNeeded() async {
        guard explorePosts.isEmpty else { return }
        await loadMoreExplore()
    }

    func loadMoreExplore() async {
        guard !isLoadingExplore, hasMoreExplorePages else { return }
        isLoadingExplore = true
        defer { isLoadingExplore = false }
        do {
            let page = try await firestoreService.fetchTrendingPosts(cursor: exploreCursor, pageSize: 21)
            explorePosts.append(contentsOf: page.posts)
            exploreCursor = page.nextCursor
            hasMoreExplorePages = page.nextCursor != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshExplore() async {
        explorePosts = []
        exploreCursor = nil
        hasMoreExplorePages = true
        await loadMoreExplore()
    }
}
