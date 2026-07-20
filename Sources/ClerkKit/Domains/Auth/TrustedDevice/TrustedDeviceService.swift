//
//  TrustedDeviceService.swift
//  Clerk
//

import Foundation

protocol TrustedDeviceServiceProtocol: Sendable {
  @MainActor func list() async throws -> [TrustedDevice]
  @MainActor func prepareEnrollment(params: TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge
  @MainActor func attemptEnrollment(params: TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice
  @MainActor func validateSignInCredential(trustedDeviceId: String) async throws -> TrustedDeviceValidation
  @MainActor func revoke(trustedDeviceId: String) async throws -> TrustedDevice
}

final class TrustedDeviceService: TrustedDeviceServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func list() async throws -> [TrustedDevice] {
    let request = Request<ClientResponse<[TrustedDevice]>>(
      path: "/v1/me/trusted_devices",
      method: .get,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareEnrollment(params: TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge {
    let request = Request<ClientResponse<TrustedDeviceChallenge>>(
      path: "/v1/me/trusted_devices/prepare",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptEnrollment(params: TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice {
    let request = Request<ClientResponse<TrustedDevice>>(
      path: "/v1/me/trusted_devices/attempt",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: params
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func validateSignInCredential(trustedDeviceId: String) async throws -> TrustedDeviceValidation {
    let request = Request<ClientResponse<TrustedDeviceValidation>>(
      path: "/v1/client/trusted_devices/validate",
      method: .post,
      body: TrustedDeviceValidation.Params(trustedDeviceId: trustedDeviceId)
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func revoke(trustedDeviceId: String) async throws -> TrustedDevice {
    let request = Request<ClientResponse<TrustedDevice>>(
      path: "/v1/me/trusted_devices/\(trustedDeviceId)",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
