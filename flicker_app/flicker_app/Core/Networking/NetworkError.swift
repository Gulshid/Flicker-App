import Foundation

enum AppError: LocalizedError {
    case notAuthenticated
    case invalidInput(String)
    case uploadFailed(String)
    case firestoreError(String)
    case compressionFailed
    case notFound(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to do that."
        case .invalidInput(let msg):
            return msg
        case .uploadFailed(let msg):
            return "Upload failed: \(msg)"
        case .firestoreError(let msg):
            return "Something went wrong: \(msg)"
        case .compressionFailed:
            return "Couldn't process that image. Try a different one."
        case .notFound(let msg):
            return msg
        case .unknown(let err):
            return err.localizedDescription
        }
    }
}
