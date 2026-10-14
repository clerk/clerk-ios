//
//  SignInWithAppleHelper.swift
//

#if canImport(AuthenticationServices) && !os(watchOS)

import AuthenticationServices
import CryptoKit
import Foundation

final class SignInWithAppleHelper: NSObject {
  private var continuation: CheckedContinuation<ASAuthorization, Error>?

  private func generateNonce() -> String {
    let data = Data((0 ..< 32).map { _ in UInt8.random(in: UInt8.min ... UInt8.max) })

    let hashedData = SHA256.hash(data: data)

    let base64String = Data(hashedData).base64EncodedString()
    return
      base64String
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
  }

  @MainActor
  func start(requestedScopes: [ASAuthorization.Scope]) async throws -> ASAuthorization {
    try await withCheckedThrowingContinuation { continuation in
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

  @MainActor
  static func getAppleIdCredential(requestedScopes: [ASAuthorization.Scope]) async throws -> ASAuthorizationAppleIDCredential {
    let authManager = SignInWithAppleHelper()
    let authorization = try await authManager.start(requestedScopes: requestedScopes)

    guard let appleIdCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      throw ClerkClientError(message: "Unable to get your Apple ID credential.", localizationBundle: .module)
    }

    return appleIdCredential
  }
}

extension SignInWithAppleHelper: ASAuthorizationControllerDelegate {
  func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    continuation?.resume(returning: authorization)
  }

  func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: any Error) {
    continuation?.resume(throwing: Self.localizedAuthorizationError(error))
  }

  static func localizedAuthorizationError(_ error: any Error) -> any Error {
    let nsError = error as NSError
    guard nsError.domain == ASAuthorizationError.errorDomain,
          nsError.code == ASAuthorizationError.Code.unknown.rawValue
    else {
      return error
    }

    var userInfo = nsError.userInfo
    userInfo[NSLocalizedDescriptionKey] = String(
      localized: "Unable to sign in with Apple. Make sure you're signed in to your Apple Account in Settings, then try again.",
      bundle: .module
    )
    return ASAuthorizationError(.unknown, userInfo: userInfo)
  }
}

extension SignInWithAppleHelper: ASAuthorizationControllerPresentationContextProviding {
  @MainActor
  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    PresentationAnchorProvider.current
  }
}

extension ASAuthorizationAppleIDCredential {
  var tokenString: String {
    identityToken.flatMap { String(data: $0, encoding: .utf8) } ?? ""
  }
}

#endif
