import Foundation

protocol MediaServiceProtocol {
    func uploadImage(
        _ data: Data,
        fileName: String,
        progress: ((Double) -> Void)?
    ) async throws -> String

    func uploadVideo(
        _ data: Data,
        fileName: String,
        progress: ((Double) -> Void)?
    ) async throws -> String
}

extension MediaServiceProtocol {
    /// Convenience overload for callers that don't care about progress.
    func uploadImage(_ data: Data, fileName: String) async throws -> String {
        try await uploadImage(data, fileName: fileName, progress: nil)
    }
}

/// Uploads directly to Cloudinary using an UNSIGNED upload preset.
/// This is intentional: with no paid backend/Cloud Functions, there is
/// nothing available to sign requests server-side, so an unsigned preset
/// is the correct, safe way to let the client upload directly.
///
/// Before shipping, lock down abuse in the Cloudinary dashboard:
/// Settings → Upload → your preset → restrict allowed formats,
/// max file size, and target folder.
final class CloudinaryService: NSObject, MediaServiceProtocol {

    // TODO: Replace with your own Cloudinary cloud name and unsigned preset name.
    private let cloudName = "df0saqabg"
    private let uploadPreset = "flicker_unsigned"

    /// Retries transient network failures (timeouts, dropped connections)
    /// with a short backoff. Doesn't retry on 4xx — a bad preset/file
    /// won't succeed on attempt two.
    private let maxRetries = 2

    func uploadImage(
        _ data: Data,
        fileName: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> String {
        try await upload(data, fileName: fileName, resourceType: "image", contentType: "image/jpeg", progress: progress)
    }

    func uploadVideo(
        _ data: Data,
        fileName: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> String {
        try await upload(data, fileName: fileName, resourceType: "video", contentType: "video/mp4", progress: progress)
    }

    // MARK: - Core upload + retry

    private func upload(
        _ data: Data,
        fileName: String,
        resourceType: String,
        contentType: String,
        progress: ((Double) -> Void)?
    ) async throws -> String {
        var lastError: Error = AppError.uploadFailed("Unknown error")

        for attempt in 0...maxRetries {
            do {
                return try await performUpload(
                    data,
                    fileName: fileName,
                    resourceType: resourceType,
                    contentType: contentType,
                    progress: progress
                )
            } catch let error as AppError {
                lastError = error
                // Don't burn retries on a client-side problem (bad preset, oversized file, etc).
                if case .uploadFailed = error, attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: backoffNanoseconds(for: attempt))
                    continue
                }
                throw error
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: backoffNanoseconds(for: attempt))
                    continue
                }
            }
        }
        throw lastError
    }

    private func backoffNanoseconds(for attempt: Int) -> UInt64 {
        // 0.5s, 1.5s — short enough not to stall a form, long enough to
        // ride out a brief connectivity blip.
        let seconds = 0.5 + Double(attempt) * 1.0
        return UInt64(seconds * 1_000_000_000)
    }

    private func performUpload(
        _ data: Data,
        fileName: String,
        resourceType: String,
        contentType: String,
        progress: ((Double) -> Void)?
    ) async throws -> String {
        guard let url = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/\(resourceType)/upload") else {
            throw AppError.uploadFailed("Invalid Cloudinary URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("upload_preset", uploadPreset)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let delegate = progress.map { UploadProgressDelegate(onProgress: $0) }
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.upload(for: request, from: body, delegate: delegate)
        } catch {
            throw AppError.uploadFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.uploadFailed("Server returned an error")
        }

        struct CloudinaryResponse: Decodable { let secure_url: String }
        do {
            let decoded = try JSONDecoder().decode(CloudinaryResponse.self, from: responseData)
            return decoded.secure_url
        } catch {
            throw AppError.uploadFailed("Unexpected response from Cloudinary")
        }
    }
}

/// Reports fractional upload progress (0...1) via URLSession's per-task
/// delegate hook. Kept private to this file — MediaUploadService is the
/// public-facing place UI code observes progress from.
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(fraction)
    }
}
