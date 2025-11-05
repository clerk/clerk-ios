//
//  EmailAddressService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
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

  // Convenience initializer for dependency injection
  init(dependencies: Dependencies) {
    self.apiClient = dependencies.apiClient
  }

  @MainActor
  func create(email: String) async throws -> EmailAddress {
    let request = Request<ClientResponse<EmailAddress>>(
      path: "v1/me/email_addresses",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["email_address": email]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareVerification(emailAddressId: String, strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress {
    let request = Request<ClientResponse<EmailAddress>>(
      path: "/v1/me/email_addresses/\(emailAddressId)/prepare_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: strategy.requestBody
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(emailAddressId: String, strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress {
    let request = Request<ClientResponse<EmailAddress>>(
      path: "/v1/me/email_addresses/\(emailAddressId)/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: strategy.requestBody
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func destroy(emailAddressId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/email_addresses/\(emailAddressId)",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }
}
