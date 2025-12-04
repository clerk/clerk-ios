//
//  SignInService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import Foundation

protocol SignInServiceProtocol: Sendable {
  // Create
  @MainActor func create(params: SignIn.CreateParams) async throws -> SignIn

  // First factor
  @MainActor func prepareFirstFactor(signInId: String, params: SignIn.PrepareFirstFactorParams) async throws -> SignIn
  @MainActor func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn

  // Second factor
  @MainActor func prepareSecondFactor(signInId: String, params: SignIn.PrepareSecondFactorParams) async throws -> SignIn
  @MainActor func attemptSecondFactor(signInId: String, params: SignIn.AttemptSecondFactorParams) async throws -> SignIn

  // Password reset
  @MainActor func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) async throws -> SignIn

  // Get/reload
  @MainActor func get(signInId: String, params: SignIn.GetParams) async throws -> SignIn
}

final class SignInService: SignInServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // MARK: - Create

  @MainActor
  func create(params: SignIn.CreateParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - First Factor

  @MainActor
  func prepareFirstFactor(signInId: String, params: SignIn.PrepareFirstFactorParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)/prepare_first_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptFirstFactor(signInId: String, params: SignIn.AttemptFirstFactorParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)/attempt_first_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - Second Factor

  @MainActor
  func prepareSecondFactor(signInId: String, params: SignIn.PrepareSecondFactorParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)/prepare_second_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptSecondFactor(signInId: String, params: SignIn.AttemptSecondFactorParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)/attempt_second_factor",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - Password Reset

  @MainActor
  func resetPassword(signInId: String, params: SignIn.ResetPasswordParams) async throws -> SignIn {
    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)/reset_password",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - Get/Reload

  @MainActor
  func get(signInId: String, params: SignIn.GetParams) async throws -> SignIn {
    var queryParams: [(String, String?)] = []
    if let rotatingTokenNonce = params.rotatingTokenNonce {
      queryParams.append(
        (
          "rotating_token_nonce",
          rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        )
      )
    }

    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/\(signInId)",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }
}
