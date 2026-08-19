import AVFoundation
import Foundation

/// Client-side transcode + downscale before anything goes over the
/// network — the video counterpart to `ImageCompressor`. Raw clips
/// straight out of the Photos library (4K/60fps, ProRes, etc.) can be
/// hundreds of MB; without this step that entire file gets pushed over
/// upload bandwidth (which is usually far slower than download), which
/// is what makes "Uploading…" crawl. Re-encoding at a lower preset
/// typically shrinks a raw phone clip 5–10x with little visible
/// quality loss on a phone screen.
enum VideoCompressor {

    /// Transcodes the video at `sourceURL` using an `AVAssetExportSession`
    /// preset, writes it to a temp file, and returns the resulting bytes.
    /// Caller is responsible for cleaning up `sourceURL` if it was a
    /// temporary copy (e.g. from a PhotosPicker import).
    static func compress(
        sourceURL: URL,
        preset: String = AVAssetExportPresetMediumQuality
    ) async throws -> Data {
        let asset = AVURLAsset(url: sourceURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw AppError.compressionFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        // Moves the moov atom to the front so playback/upload can start
        // streaming before the whole file is written — also trims a bit
        // of dead weight from the container itself.
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        defer { try? FileManager.default.removeItem(at: outputURL) }

        guard exportSession.status == .completed else {
            throw AppError.compressionFailed
        }

        return try Data(contentsOf: outputURL)
    }
}

/// `Transferable` wrapper that lets `PhotosPickerItem` hand back a file
/// `URL` instead of loading the entire raw video into memory as `Data`.
/// The picker's underlying file is copied into our own temp directory
/// because the original is only guaranteed to exist for the duration of
/// the import call.
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { picked in
            SentTransferredFile(picked.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
