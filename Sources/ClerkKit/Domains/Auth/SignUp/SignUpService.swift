//
//  SignUpService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import AuthenticationServices
import Foundation

protocol SignUpServiceProtocol: Sendable {
  // Create
  @MainActor func create(params: SignUp.CreateParams) async throws -> SignUp

  // Verification
  @MainActor func prepareVerification(signUpId: String, params: SignUp.PrepareVerificationParams) async throws -> SignUp
  @MainActor func attemptVerification(signUpId: String, params: SignUp.AttemptVerificationParams) async throws -> SignUp

  // Update
  @MainActor func update(signUpId: String, params: SignUp.UpdateParams) async throws -> SignUp

  // Get/reload
  @MainActor func get(signUpId: String, params: SignUp.GetParams) async throws -> SignUp
}

final class SignUpService: SignUpServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // MARK: - Create

  @MainActor
  func create(params: SignUp.CreateParams) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - Verification

  @MainActor
  func prepareVerification(signUpId: String, params: SignUp.PrepareVerificationParams) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)/prepare_verification",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(signUpId: String, params: SignUp.AttemptVerificationParams) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)/attempt_verification",
      method: .post,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - Update

  @MainActor
  func update(signUpId: String, params: SignUp.UpdateParams) async throws -> SignUp {
    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)",
      method: .patch,
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  // MARK: - Get/Reload

  @MainActor
  func get(signUpId: String, params: SignUp.GetParams) async throws -> SignUp {
    var queryParams: [(String, String?)] = []
    if let rotatingTokenNonce = params.rotatingTokenNonce {
      queryParams.append(
        (
          "rotating_token_nonce",
          rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        )
      )
    }

    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/\(signUpId)",
      method: .get,
      query: queryParams
    )

    return try await apiClient.send(request).value.response
  }
}
