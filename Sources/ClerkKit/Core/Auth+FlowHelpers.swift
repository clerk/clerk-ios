//
//  Auth+FlowHelpers.swift
//  Clerk
//

import AuthenticationServices
import Foundation

// MARK: - Flow Helpers

extension Auth {
  func externalAuthenticationURL(_ redirectUrl: String?) throws -> URL {
    guard let redirectUrl,
          let url = URL(string: redirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    return url
  }

  @discardableResult
  func reload(_ signIn: SignIn, rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await signInService.get(signInId: signIn.id, params: .init(rotatingTokenNonce: rotatingTokenNonce))
  }

  @discardableResult
  func handleTransferFlow(
    for signIn: SignIn,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    guard transferable, signIn.needsTransferToSignUp else {
      return .signIn(signIn)
    }

    let signUp = try await signUpService.create(params: .init(transfer: true))
    return .signUp(signUp)
  }

  @discardableResult
  func handleRedirectCallbackUrl(
    _ url: URL,
    for signIn: SignIn,
    transferable: Bool = true
  ) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignIn = try await reload(signIn, rotatingTokenNonce: nonce)
      if let error = updatedSignIn.firstFactorVerification?.error {
        throw error
      }
      return .signIn(updatedSignIn)
    }

    let updatedSignIn = try await reload(signIn)
    let result = try await handleTransferFlow(for: updatedSignIn, transferable: transferable)

    switch result {
    case .signIn(let signIn):
      if let error = signIn.firstFactorVerification?.error {
        throw error
      }
    case .signUp(let signUp):
      if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
    }

    return result
  }

  @discardableResult
  func reload(_ signUp: SignUp, rotatingTokenNonce: String? = nil) async throws -> SignUp {
    try await signUpService.get(signUpId: signUp.id, params: .init(rotatingTokenNonce: rotatingTokenNonce))
  }

  func handleTransferFlow(for signUp: SignUp) async throws -> TransferFlowResult {
    guard signUp.needsTransferToSignIn else {
      return .signUp(signUp)
    }

    let signIn = try await signInService.create(params: .init(transfer: true))
    return .signIn(signIn)
  }

  @discardableResult
  func handleRedirectCallbackUrl(_ url: URL, for signUp: SignUp) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignUp = try await reload(signUp, rotatingTokenNonce: nonce)
      if let verification = updatedSignUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
      return .signUp(updatedSignUp)
    }

    let updatedSignUp = try await reload(signUp)
    let result = try await handleTransferFlow(for: updatedSignUp)

    switch result {
    case .signIn(let signIn):
      if let error = signIn.firstFactorVerification?.error {
        throw error
      }
    case .signUp(let signUp):
      if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
         let error = verification.error
      {
        throw error
      }
    }

    return result
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  func getCredentialForPasskey(
    from signIn: SignIn,
    autofill: Bool = false,
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws -> String {
    guard
      let nonceJSON = signIn.firstFactorVerification?.nonce?.toJSON(),
      let challengeString = nonceJSON["challenge"]?.stringValue,
      let challenge = challengeString.dataFromBase64URL()
    else {
      throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
    }

    let manager = PasskeyHelper()
    let authorization: ASAuthorization

    #if os(iOS) && !targetEnvironment(macCatalyst)
    if autofill {
      authorization = try await manager.beginAutoFillAssistedPasskeySignIn(challenge: challenge)
    } else {
      authorization = try await manager.signIn(
        challenge: challenge,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    }
    #else
    authorization = try await manager.signIn(
      challenge: challenge,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )
    #endif

    guard
      let credentialAssertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion,
      let authenticatorData = credentialAssertion.rawAuthenticatorData
    else {
      throw ClerkClientError(message: "Invalid credential type.")
    }

    let publicKeyCredential: [String: Any] = [
      "id": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
      "rawId": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
      "type": "public-key",
      "response": [
        "authenticatorData": authenticatorData.base64EncodedString().base64URLFromBase64String(),
        "clientDataJSON": credentialAssertion.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
        "signature": credentialAssertion.signature.base64EncodedString().base64URLFromBase64String(),
        "userHandle": credentialAssertion.userID.base64EncodedString().base64URLFromBase64String(),
      ],
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: publicKeyCredential)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw ClerkClientError(message: "Unable to encode the passkey credential.")
    }

    return jsonString
  }
  #endif
}
