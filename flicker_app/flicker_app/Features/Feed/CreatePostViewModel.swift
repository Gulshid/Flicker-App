import Foundation
import PhotosUI
import Observation

/// Per-item state for the create-post media grid, so the UI can show a
/// progress ring on exactly the item that's still uploading and a retry
/// affordance on exactly the one that failed.
enum PostMediaItemState: Equatable {
    case compressing
    case uploading(progress: Double)
    case uploaded(url: String)
    case failed(message: String)
}

/// Multi-item version of the single-item flow in `MediaUploadService`
/// (which stays as-is for the avatar picker). Post creation needs several
/// images uploading — each tracked independently — followed by one
/// Firestore write once they've all finished, so this owns its own small
/// per-item state machine rather than reusing that class N times over.
@MainActor
@Observable
final class CreatePostViewModel {
    struct MediaItem: Identifiable {
        let id = UUID()
        var data: Data
        var state: PostMediaItemState
    }

    private(set) var items: [MediaItem] = []
    var caption: String = ""
    private(set) var isPosting = false
    var errorMessage: String?

    private let mediaService: MediaServiceProtocol
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

    /// Maximum images/videos in one post — keeps upload time and
    /// Cloudinary free-tier usage bounded.
    let maxItems = 6

    init(
        mediaService: MediaServiceProtocol = DIContainer.shared.mediaService,
        firestoreService: FirestoreServiceProtocol = DIContainer.shared.firestoreService,
        authService: AuthServiceProtocol = DIContainer.shared.authService
    ) {
        self.mediaService = mediaService
        self.firestoreService = firestoreService
        self.authService = authService
    }

    var canPost: Bool {
        !items.isEmpty
            && !isPosting
            && items.allSatisfy { if case .uploaded = $0.state { return true } else { return false } }
    }

    var isUploading: Bool {
        items.contains { if case .uploading = $0.state { return true } else if case .compressing = $0.state { return true } else { return false } }
    }

    /// Loads, compresses, and kicks off an upload for each newly-picked
    /// item. Existing items are left untouched, so re-opening the picker
    /// to add more photos doesn't restart uploads already in flight.
    func addItems(_ pickerItems: [PhotosPickerItem]) async {
        for pickerItem in pickerItems.prefix(max(0, maxItems - items.count)) {
            guard let rawData = try? await pickerItem.loadTransferable(type: Data.self) else { continue }
            guard let compressed = ImageCompressor.compress(data: rawData) else { continue }
            let item = MediaItem(data: compressed, state: .compressing)
            items.append(item)
            await upload(itemId: item.id)
        }
    }

    private func upload(itemId: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].state = .uploading(progress: 0)
        let data = items[index].data
        do {
            let fileName = "\(UUID().uuidString).jpg"
            let url = try await mediaService.uploadImage(data, fileName: fileName) { [weak self] fraction in
                guard let self else { return }
                Task { @MainActor in
                    guard let i = self.items.firstIndex(where: { $0.id == itemId }) else { return }
                    self.items[i].state = .uploading(progress: fraction)
                }
            }
            guard let i = items.firstIndex(where: { $0.id == itemId }) else { return }
            items[i].state = .uploaded(url: url)
        } catch {
            guard let i = items.firstIndex(where: { $0.id == itemId }) else { return }
            items[i].state = .failed(message: error.localizedDescription)
        }
    }

    func retry(itemId: UUID) async {
        await upload(itemId: itemId)
    }

    func remove(itemId: UUID) {
        items.removeAll { $0.id == itemId }
    }

    /// Writes the post once every item has a Cloudinary URL. Returns the
    /// created post so the caller (CreatePostView) can hand it to
    /// FeedViewModel.prependNewPost.
    func submit() async -> Post? {
        guard canPost else { return nil }
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return nil
        }
        isPosting = true
        defer { isPosting = false }

        let urls = items.compactMap { item -> String? in
            if case .uploaded(let url) = item.state { return url }
            return nil
        }

        do {
            // One extra read for username/avatar to denormalize onto the
            // post. SessionStore caches this too, but this ViewModel
            // isn't wired to the environment, and one read per post
            // created is well within the free-tier quota.
            let author = try await currentAuthorInfo(uid: uid)
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            return try await firestoreService.createPost(
                authorId: uid,
                authorUsername: author.username,
                authorAvatarURL: author.avatarURL,
                mediaURLs: urls,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func currentAuthorInfo(uid: String) async throws -> (username: String, avatarURL: String?) {
        let user = try await firestoreService.fetchUser(uid)
        return (user.username, user.avatarURL)
    }
}
