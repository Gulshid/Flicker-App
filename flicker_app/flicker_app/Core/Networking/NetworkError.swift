import Foundation

enum AppError: LocalizedError {
    case notAuthenticated
    case invalidInput(String)
    case uploadFailed(String)
    case firestoreError(String)
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
        case .unknown(let err):
            return err.localizedDescription
        }
    }
}
