import Foundation
import PhotosUI
import Observation

/// One reusable state machine for "pick a photo → compress → upload →
/// get a URL back", used by both avatar upload (Phase 3) and post
/// creation (Phase 5). Views bind to `state` and `progress` directly —
/// no callback plumbing needed.
enum MediaUploadState: Equatable {
    case idle
    case compressing
    case uploading
    case success(url: String)
    case failed(message: String)
}

@MainActor
@Observable
final class MediaUploadService {
    private(set) var state: MediaUploadState = .idle
    private(set) var progress: Double = 0

    private let mediaService: MediaServiceProtocol
    private var lastData: Data?

    init(mediaService: MediaServiceProtocol = DIContainer.shared.mediaService) {
        self.mediaService = mediaService
    }

    /// Loads the picked item, compresses it, and uploads it — the full
    /// pipeline for one image, start to finish.
    func upload(item: PhotosPickerItem) async {
        state = .compressing
        progress = 0

        guard let rawData = try? await item.loadTransferable(type: Data.self) else {
            state = .failed(message: "Couldn't load that photo.")
            return
        }

        guard let compressed = ImageCompressor.compress(data: rawData) else {
            state = .failed(message: AppError.compressionFailed.localizedDescription)
            return
        }

        lastData = compressed
        await performUpload(compressed)
    }

    /// Retries the last upload without re-picking or re-compressing —
    /// this is what the "retry on failure" UI in Phase 4 calls.
    func retry() async {
        guard let lastData else { return }
        await performUpload(lastData)
    }

    func reset() {
        state = .idle
        progress = 0
        lastData = nil
    }

    private func performUpload(_ data: Data) async {
        state = .uploading
        progress = 0
        do {
            let fileName = "\(UUID().uuidString).jpg"
            let url = try await mediaService.uploadImage(data, fileName: fileName) { [weak self] fraction in
                guard let self else { return }
                Task { @MainActor in
                    self.progress = fraction
                }
            }
            state = .success(url: url)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
