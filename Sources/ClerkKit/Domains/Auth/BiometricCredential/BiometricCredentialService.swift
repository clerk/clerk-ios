//
//  BiometricCredentialService.swift
//  Clerk
//

import Foundation

protocol BiometricCredentialServiceProtocol: Sendable {
  @MainActor func list() async throws -> [BiometricCredential]
  @MainActor func prepareEnrollment(
    sessionId: String,
    params: BiometricCredential.PrepareEnrollmentParams
  ) async throws -> BiometricCredentialChallenge
  @MainActor func attemptEnrollment(
    sessionId: String,
    params: BiometricCredential.AttemptEnrollmentParams
  ) async throws -> BiometricCredential
  @MainActor func validateSignInCredential(biometricCredentialId: String) async throws -> BiometricCredentialValidation
  @MainActor func revoke(
    biometricCredentialId: String,
    sessionId: String?
  ) async throws -> BiometricCredential
}

final class BiometricCredentialService: BiometricCredentialServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func list() async throws -> [BiometricCredential] {
    let request = Request<ClientResponse<[BiometricCredential]>>(
      path: "/v1/me/biometric_credentials",
      method: .get,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareEnrollment(
    sessionId: String,
    params: BiometricCredential.PrepareEnrollmentParams
  ) async throws -> BiometricCredentialChallenge {
    let request = Request<ClientResponse<BiometricCredentialChallenge>>(
      path: "/v1/me/biometric_credentials/prepare",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptEnrollment(
    sessionId: String,
    params: BiometricCredential.AttemptEnrollmentParams
  ) async throws -> BiometricCredential {
    let request = Request<ClientResponse<BiometricCredential>>(
      path: "/v1/me/biometric_credentials/attempt",
      method: .post,
      query: [("_clerk_session_id", value: sessionId)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func validateSignInCredential(biometricCredentialId: String) async throws -> BiometricCredentialValidation {
    let request = Request<ClientResponse<BiometricCredentialValidation>>(
      path: "/v1/client/biometric_credentials/validate",
      method: .post,
      body: BiometricCredentialValidation.Params(biometricCredentialId: biometricCredentialId)
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func revoke(
    biometricCredentialId: String,
    sessionId: String?
  ) async throws -> BiometricCredential {
    let request = Request<ClientResponse<BiometricCredential>>(
      path: "/v1/me/biometric_credentials/\(biometricCredentialId)",
      method: .delete,
      query: [("_clerk_session_id", value: sessionId)]
    )

    return try await apiClient.send(request).value.response
  }
}
