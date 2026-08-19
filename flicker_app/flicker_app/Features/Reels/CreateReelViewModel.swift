import Foundation
import PhotosUI
import SwiftUI
import Observation

/// Backs CreateReelView: exactly one video, uploaded via
/// `MediaServiceProtocol.uploadVideo` (already built in Phase 4, unused
/// until now) and written as a normal `posts/{postId}` doc with
/// `hasVideo: true` — a reel IS a post, just one the Reels tab's query
/// filters down to. This deliberately does not reuse
/// `CreatePostViewModel`: that one is a multi-item *image* pipeline
/// (compression, thumbnailing assumptions baked in), and forcing video
/// through it would be more invasive than a small dedicated flow.
@MainActor
@Observable
final class CreateReelViewModel {
    enum UploadState: Equatable {
        case idle
        case loading
        case uploading(progress: Double)
        case uploaded(url: String)
        case failed(message: String)
    }

    private(set) var state: UploadState = .idle
    var caption: String = ""
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

    func pickedVideo(_ item: PhotosPickerItem) async {
        state = .loading

        // Load a file URL rather than raw `Data` — pulling the whole
        // original clip into memory up front isn't necessary and this
        // keeps large files off the heap until we're ready for them.
        guard let picked = try? await item.loadTransferable(type: PickedVideo.self) else {
            state = .failed(message: "Couldn't load that video.")
            return
        }
        defer { try? FileManager.default.removeItem(at: picked.url) }

        // Transcode/downscale before it ever touches the network. This
        // is the step that keeps reel uploads fast — without it we'd be
        // pushing the raw, full-resolution Photos library file, which
        // can be hundreds of MB.
        let compressed: Data
        do {
            compressed = try await VideoCompressor.compress(sourceURL: picked.url)
        } catch {
            state = .failed(message: AppError.compressionFailed.localizedDescription)
            return
        }

        state = .uploading(progress: 0)
        do {
            let fileName = "\(UUID().uuidString).mp4"
            let url = try await mediaService.uploadVideo(compressed, fileName: fileName) { [weak self] fraction in
                Task { @MainActor in
                    self?.state = .uploading(progress: fraction)
                }
            }
            state = .uploaded(url: url)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func submit() async -> Post? {
        guard case .uploaded(let url) = state else { return nil }
        guard let uid = authService.currentUserId else {
            errorMessage = AppError.notAuthenticated.localizedDescription
            return nil
        }
        isPosting = true
        defer { isPosting = false }
        do {
            let user = try await firestoreService.fetchUser(uid)
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            return try await firestoreService.createPost(
                authorId: uid,
                authorUsername: user.username,
                authorAvatarURL: user.avatarURL,
                mediaURLs: [url],
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption,
                hasVideo: true
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
