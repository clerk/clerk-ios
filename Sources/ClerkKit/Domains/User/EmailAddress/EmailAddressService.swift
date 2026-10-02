//
//  EmailAddressService.swift
//  Clerk
//

import Foundation

protocol EmailAddressServiceProtocol: Sendable {
  @MainActor func create(email: String) async throws -> EmailAddress
  @MainActor func prepareVerification(emailAddressId: String, strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress
  @MainActor func attemptVerification(emailAddressId: String, strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress
  @MainActor func destroy(emailAddressId: String) async throws -> DeletedObject
}

final class EmailAddressService: EmailAddressServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func create(email: String) async throws -> EmailAddress {
    let request = Request<ClientResponse<EmailAddress>>(
      path: "v1/me/email_addresses",
      method: .post,
      scopedToActiveSession: true,
      body: ["email_address": email]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareVerification(emailAddressId: String, strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress {
    let request = Request<ClientResponse<EmailAddress>>(
      path: "/v1/me/email_addresses/\(emailAddressId)/prepare_verification",
      method: .post,
      scopedToActiveSession: true,
      body: strategy.requestBody
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(emailAddressId: String, strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress {
    let request = Request<ClientResponse<EmailAddress>>(
      path: "/v1/me/email_addresses/\(emailAddressId)/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: strategy.requestBody
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func destroy(emailAddressId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/email_addresses/\(emailAddressId)",
      method: .delete,
      scopedToActiveSession: true
    )

    return try await apiClient.send(request).value.response
  }
}
