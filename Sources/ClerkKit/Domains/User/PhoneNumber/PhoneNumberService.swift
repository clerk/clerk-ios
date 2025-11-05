//
//  PhoneNumberService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import Foundation

protocol PhoneNumberServiceProtocol: Sendable {
  @MainActor func create(phoneNumber: String) async throws -> PhoneNumber
  @MainActor func delete(phoneNumberId: String) async throws -> DeletedObject
  @MainActor func prepareVerification(phoneNumberId: String) async throws -> PhoneNumber
  @MainActor func attemptVerification(phoneNumberId: String, code: String) async throws -> PhoneNumber
  @MainActor func makeDefaultSecondFactor(phoneNumberId: String) async throws -> PhoneNumber
  @MainActor func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber
}

final class PhoneNumberService: PhoneNumberServiceProtocol {

  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // Convenience initializer for dependency injection
  init(dependencies: Dependencies) {
    self.apiClient = dependencies.apiClient
  }

  @MainActor
  func create(phoneNumber: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["phone_number": phoneNumber]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete(phoneNumberId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .delete,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareVerification(phoneNumberId: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)/prepare_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["strategy": "phone_code"]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(phoneNumberId: String, code: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)/attempt_verification",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["code": code]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func makeDefaultSecondFactor(phoneNumberId: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .patch,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["default_second_factor": true]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .patch,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: ["reserved_for_second_factor": reserved]
    )

    return try await apiClient.send(request).value.response
  }
}
