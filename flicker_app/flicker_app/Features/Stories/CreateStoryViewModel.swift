import Foundation
import PhotosUI
import Observation

/// Backs CreateStoryView: one photo or video, picked, uploaded, and
/// written as a stories/{storyId} doc. A trimmed-down cousin of
/// `MediaUploadService` (image-only) that also knows how to push a video
/// straight through `MediaServiceProtocol.uploadVideo` — no compression
/// step for video, since `ImageCompressor` only handles stills.
@MainActor
@Observable
final class CreateStoryViewModel {
    enum UploadState: Equatable {
        case idle
        case loading
        case uploading(progress: Double)
        case uploaded(url: String, isVideo: Bool)
        case failed(message: String)
    }

    private(set) var state: UploadState = .idle
    private(set) var isPosting = false
    var errorMessage: String?

    private let mediaService: MediaServiceProtocol
    private let firestoreService: FirestoreServiceProtocol
    private let authService: AuthServiceProtocol

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
        if case .uploaded = state { return true }
        return false
    }

    var isBusy: Bool {
        switch state {
        case .loading, .uploading: return true
        default: return false
        }
    }

    func pickedPhoto(_ item: PhotosPickerItem) async {
        state = .loading
        guard let rawData = try? await item.loadTransferable(type: Data.self) else {
            state = .failed(message: "Couldn't load that photo.")
            return
        }
        guard let compressed = ImageCompressor.compress(data: rawData) else {
            state = .failed(message: AppError.compressionFailed.localizedDescription)
            return
        }
        await upload(compressed, isVideo: false)
    }

    func pickedVideo(_ item: PhotosPickerItem) async {
        state = .loading
        // Loaded as raw Data, same as the image path — fine for the
        // short clips a story is meant to be. A multi-minute video would
        // be worth switching to a file-URL-based Transferable instead to
        // avoid holding the whole thing in memory at once.
        guard let rawData = try? await item.loadTransferable(type: Data.self) else {
            state = .failed(message: "Couldn't load that video.")
            return
        }
        await upload(rawData, isVideo: true)
    }

    private func upload(_ data: Data, isVideo: Bool) async {
        state = .uploading(progress: 0)
        do {
            let fileName = "\(UUID().uuidString).\(isVideo ? "mp4" : "jpg")"
            let progressHandler: (Double) -> Void = { [weak self] fraction in
                Task { @MainActor in
                    self?.state = .uploading(progress: fraction)
                }
            }
            let url = isVideo
                ? try await mediaService.uploadVideo(data, fileName: fileName, progress: progressHandler)
                : try await mediaService.uploadImage(data, fileName: fileName, progress: progressHandler)
            state = .uploaded(url: url, isVideo: isVideo)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Writes the story doc once the media has a Cloudinary URL. Returns
    /// the created story so CreateStoryView can dismiss immediately —
    /// StoriesViewModel's live listener picks it up on its own.
    func post() async -> Story? {
        guard case .uploaded(let url, let isVideo) = state else { return nil }
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return nil
        }
        isPosting = true
        defer { isPosting = false }
        do {
            let user = try await firestoreService.fetchUser(uid)
            return try await firestoreService.createStory(
                authorId: uid,
                authorUsername: user.username,
                authorAvatarURL: user.avatarURL,
                mediaURL: url,
                isVideo: isVideo
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func reset() {
        state = .idle
    }
}
