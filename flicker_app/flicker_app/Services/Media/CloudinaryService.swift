import Foundation

protocol MediaServiceProtocol {
    func uploadImage(_ data: Data, fileName: String) async throws -> String
}

/// Uploads directly to Cloudinary using an UNSIGNED upload preset.
/// This is intentional: with no paid backend/Cloud Functions, there is
/// nothing available to sign requests server-side, so an unsigned preset
/// is the correct, safe way to let the client upload directly.
///
/// Before shipping, lock down abuse in the Cloudinary dashboard:
/// Settings → Upload → your preset → restrict allowed formats,
/// max file size, and target folder.
final class CloudinaryService: MediaServiceProtocol {

    // TODO: Replace with your own Cloudinary cloud name and unsigned preset name.
    private let cloudName = "YOUR_CLOUD_NAME"
    private let uploadPreset = "YOUR_UNSIGNED_PRESET"

    func uploadImage(_ data: Data, fileName: String) async throws -> String {
        guard let url = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload") else {
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
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.uploadFailed("Server returned an error")
        }

        struct CloudinaryResponse: Decodable { let secure_url: String }
        let decoded = try JSONDecoder().decode(CloudinaryResponse.self, from: responseData)
        return decoded.secure_url
    }
}
