//
//  SignInService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import AuthenticationServices
import FactoryKit
import Foundation

struct SignInService {
  var create: @MainActor (_ strategy: SignIn.CreateStrategy) async throws -> SignIn
  var createRaw: (_ params: AnyEncodable) async throws -> SignIn
  var resetPassword: (_ signIn: SignIn, _ params: SignIn.ResetPasswordParams) async throws -> SignIn
  var prepareFirstFactor: @MainActor (_ signIn: SignIn, _ prepareFirstFactorStrategy: SignIn.PrepareFirstFactorStrategy) async throws -> SignIn
  var attemptFirstFactor: (_ signIn: SignIn, _ attemptFirstFactorStrategy: SignIn.AttemptFirstFactorStrategy) async throws -> SignIn
  var prepareSecondFactor: (_ signIn: SignIn, _ prepareSecondFactorStrategy: SignIn.PrepareSecondFactorStrategy) async throws -> SignIn
  var attemptSecondFactor: (_ signIn: SignIn, _ strategy: SignIn.AttemptSecondFactorStrategy) async throws -> SignIn
  var authenticateWithRedirectCombined: (_ strategy: SignIn.AuthenticateWithRedirectStrategy, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
  var authenticateWithRedirectTwoStep: (_ signIn: SignIn, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
  var getCredentialForPasskey: (_ signIn: SignIn, _ autofill: Bool, _ preferImmediatelyAvailableCredentials: Bool) async throws -> String
  var authenticateWithIdTokenCombined: (_ provider: IDTokenProvider, _ idToken: String) async throws -> TransferFlowResult
  var authenticateWithIdTokenTwoStep: (_ signIn: SignIn) async throws -> TransferFlowResult
  var get: (_ signIn: SignIn, _ rotatingTokenNonce: String?) async throws -> SignIn
}

extension SignInService {

  static var liveValue: Self {
    .init(
      create: { strategy in
        let request = ClerkFAPI.v1.client.signIns.post(body: strategy.params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      createRaw: { params in
        let request = ClerkFAPI.v1.client.signIns.post(body: params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      resetPassword: { signIn, params in
        let request = ClerkFAPI.v1.client.signIns.id(signIn.id).resetPassword.post(params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      prepareFirstFactor: { signIn, strategy in
        let request = ClerkFAPI.v1.client.signIns.id(signIn.id).prepareFirstFactor.post(strategy.params(signIn: signIn))
        return try await Container.shared.apiClient().send(request).value.response
      },
      attemptFirstFactor: { signIn, strategy in
        let request = ClerkFAPI.v1.client.signIns.id(signIn.id).attemptFirstFactor.post(body: strategy.params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      prepareSecondFactor: { signIn, strategy in
        let request = ClerkFAPI.v1.client.signIns.id(signIn.id).prepareSecondFactor.post(strategy.params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      attemptSecondFactor: { signIn, strategy in
        let request = ClerkFAPI.v1.client.signIns.id(signIn.id).attemptSecondFactor.post(strategy.params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      authenticateWithRedirectCombined: { strategy, prefersEphemeralWebBrowserSession in
        let signIn = try await SignIn.create(strategy: strategy.signInStrategy)
        
        guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl, let url = URL(string: externalVerificationRedirectUrl) else {
          throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = await WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signIn.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
      },
      authenticateWithRedirectTwoStep: { signIn, prefersEphemeralWebBrowserSession in
        guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
          let url = URL(string: externalVerificationRedirectUrl)
        else {
          throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = await WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signIn.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
      },
      getCredentialForPasskey: { signIn, autofill, preferImmediatelyAvailableCredentials in
        #if canImport(AuthenticationServices) && !os(watchOS)
        guard
          let nonceJSON = signIn.firstFactorVerification?.nonce?.toJSON(),
          let challengeString = nonceJSON["challenge"]?.stringValue,
          let challenge = challengeString.dataFromBase64URL()
        else {
          throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
        }
        
        let manager = PasskeyHelper()
        var authorization: ASAuthorization
        
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if autofill {
          authorization = try await manager.beginAutoFillAssistedPasskeySignIn(
            challenge: challenge
          )
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
        
        let publicKeyCredential: [String: any Encodable] = [
          "id": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
          "rawId": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
          "type": "public-key",
          "response": [
            "authenticatorData": authenticatorData.base64EncodedString().base64URLFromBase64String(),
            "clientDataJSON": credentialAssertion.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
            "signature": credentialAssertion.signature.base64EncodedString().base64URLFromBase64String(),
            "userHandle": credentialAssertion.userID.base64EncodedString().base64URLFromBase64String()
          ]
        ]

          return try JSON(publicKeyCredential).debugDescription
        #else
          throw ClerkClientError(message: "Passkeys authentication is not supported on this platform.")
        #endif
      },
      authenticateWithIdTokenCombined: { provider, idToken in
        let signIn = try await SignIn.create(strategy: .idToken(provider: provider, idToken: idToken))
        return try await signIn.handleTransferFlow()
      },
      authenticateWithIdTokenTwoStep: { signIn in
        try await signIn.handleTransferFlow()
      },
      get: { signIn, rotatingTokenNonce in
        let request = ClerkFAPI.v1.client.signIns.id(signIn.id).get(rotatingTokenNonce: rotatingTokenNonce)
        let response = try await Container.shared.apiClient().send(request)
        return response.value.response
      }
    )
  }

}

extension Container {

  var signInService: Factory<SignInService> {
    self { .liveValue }
  }

}
