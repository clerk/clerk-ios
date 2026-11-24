//
//  PasskeyHelper.swift
//

#if canImport(AuthenticationServices) && !os(watchOS)

import AuthenticationServices
import Foundation

final class PasskeyHelper: NSObject {
  @MainActor
  static var controller: ASAuthorizationController?

  @MainActor
  private static var activeHelper: PasskeyHelper?

  @MainActor
  static func cancelCurrentAuthorization() {
    #if os(tvOS)
    if #available(tvOS 18.0, *) {
      controller?.cancel()
    }
    #else
    controller?.cancel()
    #endif

    controller = nil
    activeHelper?.cancelContinuation()
    activeHelper = nil
  }

  @MainActor
  private static func cancelAuthorization(for helperID: ObjectIdentifier) {
    guard let activeHelper, ObjectIdentifier(activeHelper) == helperID else { return }
    cancelCurrentAuthorization()
  }

  @MainActor
  private var defaultRelyingPartyIdentifier: String {
    guard let urlComponents = URLComponents(string: Clerk.shared.frontendApiUrl) else {
      return ""
    }

    let host = urlComponents.host ?? ""
    if host.hasPrefix("www.") {
      return String(host.dropFirst("www.".count))
    }
    return host
  }

  @MainActor
  private func publicKeyCredentialProvider(
    relyingPartyIdentifier: String?
  ) -> ASAuthorizationPlatformPublicKeyCredentialProvider {
    let identifier = relyingPartyIdentifier.map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let resolvedIdentifier = if let identifier, !identifier.isEmpty {
      identifier
    } else {
      defaultRelyingPartyIdentifier
    }
    return ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: resolvedIdentifier
    )
  }

  private var continuation: CheckedContinuation<ASAuthorization, Error>?

  @MainActor
  func credentialAssertionRequest(
    challenge: Data,
    relyingPartyIdentifier: String? = nil,
    allowedCredentialIDs: [Data] = [],
    userVerification: String? = nil
  ) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
    let publicKeyCredentialProvider = publicKeyCredentialProvider(
      relyingPartyIdentifier: relyingPartyIdentifier
    )

    let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
    assertionRequest.allowedCredentials = allowedCredentialIDs.map {
      ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
    }
    if let userVerification {
      assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference(rawValue: userVerification)
    }
    return assertionRequest
  }

  @available(iOSApplicationExtension, unavailable)
  @available(tvOSApplicationExtension, unavailable)
  @MainActor
  private func performAuthorization(
    requests: [ASAuthorizationRequest],
    start: @escaping @MainActor (ASAuthorizationController) -> Void
  ) async throws -> ASAuthorization {
    try Task.checkCancellation()
    Self.cancelCurrentAuthorization()
    let helperID = ObjectIdentifier(self)

    return try await withTaskCancellationHandler(
      operation: {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
          self.continuation = continuation
          Self.activeHelper = self

          let authController = ASAuthorizationController(authorizationRequests: requests)
          authController.delegate = self
          authController.presentationContextProvider = self
          Self.controller = authController

          start(authController)
        }
      },
      onCancel: {
        Task { @MainActor in
          Self.cancelAuthorization(for: helperID)
        }
      },
      isolation: MainActor.shared
    )
  }

  @available(iOSApplicationExtension, unavailable)
  @available(tvOSApplicationExtension, unavailable)
  @MainActor
  func signIn(
    challenge: Data,
    relyingPartyIdentifier: String? = nil,
    allowedCredentialIDs: [Data] = [],
    userVerification: String? = nil,
    preferImmediatelyAvailableCredentials: Bool
  ) async throws -> ASAuthorization {
    let assertionRequest = credentialAssertionRequest(
      challenge: challenge,
      relyingPartyIdentifier: relyingPartyIdentifier,
      allowedCredentialIDs: allowedCredentialIDs,
      userVerification: userVerification
    )

    return try await performAuthorization(requests: [assertionRequest]) { authController in
      #if !os(tvOS)

      if preferImmediatelyAvailableCredentials {
        // If credentials are available, presents a modal sign-in sheet.
        // If there are no locally saved credentials, no UI appears and
        // the system passes ASAuthorizationError.Code.canceled to call
        // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
        authController.performRequests(options: .preferImmediatelyAvailableCredentials)
      } else {
        // If credentials are available, presents a modal sign-in sheet.
        // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
        // passkey from a nearby device.
        authController.performRequests()
      }

      #else

      authController.performRequests()

      #endif
    }
  }

  #if os(iOS) && !targetEnvironment(macCatalyst)
  @available(iOSApplicationExtension, unavailable)
  @MainActor
  func beginAutoFillAssistedPasskeySignIn(
    challenge: Data,
    relyingPartyIdentifier: String? = nil,
    allowedCredentialIDs: [Data] = [],
    userVerification: String? = nil
  ) async throws -> ASAuthorization {
    let assertionRequest = credentialAssertionRequest(
      challenge: challenge,
      relyingPartyIdentifier: relyingPartyIdentifier,
      allowedCredentialIDs: allowedCredentialIDs,
      userVerification: userVerification
    )

    return try await performAuthorization(requests: [assertionRequest]) { authController in
      authController.performAutoFillAssistedRequests()
    }
  }
  #endif

  @MainActor
  func credentialRegistrationRequest(
    challenge: Data,
    name: String,
    userId: Data,
    relyingPartyIdentifier: String? = nil
  ) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
    let publicKeyCredentialProvider = publicKeyCredentialProvider(
      relyingPartyIdentifier: relyingPartyIdentifier
    )

    let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(
      challenge: challenge,
      name: name,
      userID: userId
    )
    registrationRequest.userVerificationPreference = .required
    return registrationRequest
  }

  @available(iOSApplicationExtension, unavailable)
  @available(tvOSApplicationExtension, unavailable)
  @MainActor
  func createPasskey(
    challenge: Data,
    name: String,
    userId: Data,
    relyingPartyIdentifier: String? = nil
  ) async throws -> ASAuthorization {
    let registrationRequest = credentialRegistrationRequest(
      challenge: challenge,
      name: name,
      userId: userId,
      relyingPartyIdentifier: relyingPartyIdentifier
    )

    return try await performAuthorization(requests: [registrationRequest]) { authController in
      authController.performRequests()
    }
  }

  @MainActor
  private func cancelContinuation() {
    guard let continuation else { return }
    self.continuation = nil
    continuation.resume(throwing: CancellationError())
  }

  @MainActor
  private func complete(with authorization: ASAuthorization) {
    guard let continuation else { return }
    self.continuation = nil
    Self.controller = nil
    Self.activeHelper = nil
    continuation.resume(returning: authorization)
  }

  @MainActor
  private func complete(with error: any Error) {
    guard let continuation else { return }
    self.continuation = nil
    Self.controller = nil
    Self.activeHelper = nil
    continuation.resume(throwing: error)
  }
}

extension PasskeyHelper: ASAuthorizationControllerDelegate {
  @MainActor
  func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    switch authorization.credential {
    case is ASAuthorizationPlatformPublicKeyCredentialRegistration:
      ClerkLogger.debug("A new passkey was registered")
    case is ASAuthorizationPlatformPublicKeyCredentialAssertion:
      ClerkLogger.debug("A passkey was used")
    case is ASPasswordCredential:
      ClerkLogger.debug("A password was provided")
    default:
      ClerkLogger.debug("Received an unexpected credential: \(type(of: authorization.credential))")
    }
    complete(with: authorization)
  }

  @MainActor
  func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: any Error) {
    complete(with: error)
  }
}

@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
extension PasskeyHelper: ASAuthorizationControllerPresentationContextProviding {
  @MainActor
  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    PresentationAnchorProvider.current
  }
}

#endif
