//
//  SwiftUIView.swift
//  Clerk
//
//  Created by Mike Pitre on 2/27/25.
//

import Factory
import Foundation

struct SignUpService {
  var create: @MainActor (_ strategy: SignUp.CreateStrategy, _ legalAccepted: Bool?) async throws -> SignUp
  var createRaw: (_ params: AnyEncodable) async throws -> SignUp
  var update: (_ signUp: SignUp, _ params: SignUp.UpdateParams) async throws -> SignUp
  var prepareVerification: (_ signUp: SignUp, _ strategy: SignUp.PrepareStrategy) async throws -> SignUp
  var attemptVerification: (_ signUp: SignUp, _ strategy: SignUp.AttemptStrategy) async throws -> SignUp
  var authenticateWithRedirectCombined: (_ strategy: SignUp.AuthenticateWithRedirectStrategy, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
  var authenticateWithRedirectTwoStep: (_ signUp: SignUp, _ prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
  var authenticateWithIdTokenCombined: (_ provider: IDTokenProvider, _ idToken: String) async throws -> TransferFlowResult
  var authenticateWithIdTokenTwoStep: (_ signUp: SignUp) async throws -> TransferFlowResult
  var get: (_ signUp: SignUp, _ rotatingTokenNonce: String?) async throws -> SignUp
}

extension SignUpService {

  static var liveValue: Self {
    .init(
      create: { strategy, legalAccepted in
        var params = strategy.params
        params.legalAccepted = legalAccepted
        let request = ClerkFAPI.v1.client.signUps.post(params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      createRaw: { params in
        let request = ClerkFAPI.v1.client.signUps.post(params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      update: { signUp, params in
        let request = ClerkFAPI.v1.client.signUps.id(signUp.id).patch(params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      prepareVerification: { signUp, strategy in
        let request = ClerkFAPI.v1.client.signUps.id(signUp.id).prepareVerification.post(strategy.params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      attemptVerification: { signUp, strategy in
        let request = ClerkFAPI.v1.client.signUps.id(signUp.id).attemptVerification.post(strategy.params)
        return try await Container.shared.apiClient().send(request).value.response
      },
      authenticateWithRedirectCombined: { strategy, prefersEphemeralWebBrowserSession in
        let signUp = try await SignUp.create(strategy: strategy.signUpStrategy)

        guard
          let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
          let redirectUrl = verification.externalVerificationRedirectUrl,
          let url = URL(string: redirectUrl)
        else {
          throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = await WebAuthentication(
          url: url,
          prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )

        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signUp.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
      },
      authenticateWithRedirectTwoStep: { signUp, prefersEphemeralWebBrowserSession in
        guard
          let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
          let redirectUrl = verification.externalVerificationRedirectUrl,
          let url = URL(string: redirectUrl)
        else {
          throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }

        let authSession = await WebAuthentication(
          url: url,
          prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )

        let callbackUrl = try await authSession.start()
        let transferFlowResult = try await signUp.handleOAuthCallbackUrl(callbackUrl)
        return transferFlowResult
      },
      authenticateWithIdTokenCombined: { provider, idToken in
        let signUp = try await SignUp.create(strategy: .idToken(provider: provider, idToken: idToken))
        return try await signUp.handleTransferFlow()
      },
      authenticateWithIdTokenTwoStep: { signUp in
        try await signUp.handleTransferFlow()
      },
      get: { signUp, rotatingTokenNonce in
        let request = ClerkFAPI.v1.client.signUps.id(signUp.id).get(rotatingTokenNonce: rotatingTokenNonce)
        return try await Container.shared.apiClient().send(request).value.response
      }
    )
  }

}

extension Container {

  var signUpService: Factory<SignUpService> {
    self { .liveValue }
  }

}
