//
//  ASAuth.swift
//
//
//  Created by Mike Pitre on 5/28/24.
//

#if canImport(AuthenticationServices) && !os(watchOS)

import Foundation
import AuthenticationServices
import CryptoKit

/// A helper class for managing the Sign in with Apple process.
///
/// This class simplifies the process of requesting user credentials using Sign in with Apple
/// by wrapping the necessary functionality in an async-await compatible API.
///
/// ### Example Usage
/// ```swift
/// do {
///     // Create an instance of the helper and get the Apple ID credential.
///     let appleIdCredential = try await SignInWithAppleHelper.getAppleIdCredential()
///
///     // Extract the ID token from the credential.
///     guard let idToken = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
///         // throw an error
///     }
///
///     // Authenticate with the extracted ID token.
///     try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
/// } catch {
///     // Handle any errors.
/// }
/// ```
final public class SignInWithAppleHelper: NSObject {

    /// A continuation to handle the result of the authorization process.
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    /// Generates a cryptographically secure nonce for Sign in with Apple requests.
    ///
    /// This method creates a nonce using CryptoKit's SHA256 hash function with cryptographically
    /// secure random data, following Apple's best practices for Sign in with Apple authentication.
    ///
    /// - Returns: A Base64 URL-safe encoded nonce string.
    private func generateNonce() -> String {
        // Generate 32 bytes (256 bits) of cryptographically secure random data
        let data = Data((0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max) })

        // Hash the random data using SHA256
        let hashedData = SHA256.hash(data: data)

        // Convert to Base64 URL-safe encoding (replacing + with -, / with _, and removing padding)
        let base64String = Data(hashedData).base64EncodedString()
        return
            base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Starts the Sign in with Apple authorization flow with the requested scopes.
    ///
    /// This method presents the Sign in with Apple UI and waits for the user to complete the sign-in flow.
    /// Once completed, it returns the `ASAuthorization` object with the user's credentials.
    ///
    /// - Parameters:
    ///   - requestedScopes: An array of `ASAuthorization.Scope` values that specify the scopes
    ///     of information being requested (e.g., email or full name).
    /// - Returns: An `ASAuthorization` object containing the user credentials.
    /// - Throws: An error if the authorization fails or if the user cancels the process.
    @MainActor
    func start(requestedScopes: [ASAuthorization.Scope]) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let appleRequest = appleIDProvider.createRequest()
            appleRequest.requestedScopes = requestedScopes
            appleRequest.nonce = generateNonce()

            let authorizationController = ASAuthorizationController(authorizationRequests: [appleRequest])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    /// Fetches an Apple ID credential using Sign in with Apple.
    ///
    /// This method wraps the authorization process into a single function, allowing you to retrieve
    /// the `ASAuthorizationAppleIDCredential` directly.
    ///
    /// - Parameters:
    ///   - requestedScopes: An array of `ASAuthorization.Scope` values to request specific information
    ///     such as the user's email or full name. Defaults to `[.email, .fullName]`.
    /// - Returns: An `ASAuthorizationAppleIDCredential` object containing the user's Apple ID credentials.
    /// - Throws: An error if the authorization fails or if the credential cannot be retrieved.
    @MainActor
    public static func getAppleIdCredential(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> ASAuthorizationAppleIDCredential {
        let authManager = SignInWithAppleHelper()
        let authorization = try await authManager.start(requestedScopes: requestedScopes)

        guard let appleIdCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw ClerkClientError(message: "Unable to get your Apple ID credential.")
        }

        return appleIdCredential
    }
}

extension SignInWithAppleHelper: ASAuthorizationControllerDelegate {

    /// Called when the authorization process completes successfully.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
    }

    /// Called when the authorization process fails.
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        continuation?.resume(throwing: error)
    }
}

extension SignInWithAppleHelper: ASAuthorizationControllerPresentationContextProviding {

    @MainActor
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
        #else
        ASPresentationAnchor()
        #endif
    }
}

#endif
