import Foundation

protocol AuthServiceProtocol {
    var currentUserId: String? { get }
    func signUp(email: String, password: String) async throws -> String
    func signIn(email: String, password: String) async throws -> String
    func signOut() throws
    func sendPasswordReset(email: String) async throws
    func sendEmailVerification() async throws
}
