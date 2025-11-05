//
//  SignUpService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import Foundation

protocol SignUpServiceProtocol: Sendable {
  @MainActor func create(strategy: SignUp.CreateStrategy, legalAccepted: Bool?, locale: String?) async throws -> SignUp
  @MainActor func createWithParams(params: any Encodable & Sendable) async throws -> SignUp
  @MainActor func update(signUpId: String, params: SignUp.UpdateParams) async throws -> SignUp
  @MainActor func prepareVerification(signUpId: String, strategy: SignUp.PrepareStrategy) async throws -> SignUp
  @MainActor func attemptVerification(signUpId: String, strategy: SignUp.AttemptStrategy) async throws -> SignUp
  @MainActor func get(signUpId: String, rotatingTokenNonce: String?) async throws -> SignUp

  #if !os(tvOS) && !os(watchOS)
  @MainActor func authenticateWithRedirectStatic(strategy: SignUp.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
  @MainActor func authenticateWithRedirect(signUp: SignUp, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @MainActor func authenticateWithIdTokenStatic(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult
  @MainActor func authenticateWithIdToken(signUp: SignUp) async throws -> TransferFlowResult
  #endif
}

final class SignUpService: SignUpServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func create(strategy: SignUp.CreateStrategy, legalAccepted: Bool?, locale: String?) async throws -> SignUp {
    var params = strategy.params
    params.legalAccepted = legalAccepted
    params.locale = locale ?? LocaleUtils.userLocale()

    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func createWithParams(params: any Encodable & Sendable) async throws -> SignUp {
    var body: any Encodable & Sendable = params
    if var json = try? JSON(encodable: params), case var .object(object) = json {
      if object["locale"] == nil || object["locale"] == .null {
        object["locale"] = .string(LocaleUtils.userLocale())
        json = .object(object)
      }
      body = json
    }

    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups",
      method: .post,
      body: body
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func update(signUpId: String, params: SignUp.UpdateParams) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)",
      method: .patch,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareVerification(signUpId: String, strategy: SignUp.PrepareStrategy) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)/prepare_verification",
      method: .post,
      body: strategy.params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(signUpId: String, strategy: SignUp.AttemptStrategy) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)/attempt_verification",
      method: .post,
      body: strategy.params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func get(signUpId: String, rotatingTokenNonce: String?) async throws -> SignUp {
    var queryParams: [(String, String?)] = []
    if let rotatingTokenNonce {
      queryParams.append((
        "rotating_token_nonce",
        rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      ))
    }

    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }

  #if !os(tvOS) && !os(watchOS)
  @MainActor
  func authenticateWithRedirectStatic(strategy: SignUp.AuthenticateWithRedirectStrategy, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
    let signUp = try await SignUp.create(strategy: strategy.signUpStrategy)

    guard
      let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
      let redirectUrl = verification.externalVerificationRedirectUrl,
      let url = URL(string: redirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )

    let callbackUrl = try await authSession.start()
    return try await signUp.handleOAuthCallbackUrl(callbackUrl)
  }

  @MainActor
  func authenticateWithRedirect(signUp: SignUp, prefersEphemeralWebBrowserSession: Bool) async throws -> TransferFlowResult {
    guard
      let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
      let redirectUrl = verification.externalVerificationRedirectUrl,
      let url = URL(string: redirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )

    let callbackUrl = try await authSession.start()
    return try await signUp.handleOAuthCallbackUrl(callbackUrl)
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @MainActor
  func authenticateWithIdTokenStatic(provider: IDTokenProvider, idToken: String) async throws -> TransferFlowResult {
    let signUp = try await SignUp.create(strategy: .idToken(provider: provider, idToken: idToken))
    return try await signUp.handleTransferFlow()
  }

  @MainActor
  func authenticateWithIdToken(signUp: SignUp) async throws -> TransferFlowResult {
    try await signUp.handleTransferFlow()
  }
  #endif
}
