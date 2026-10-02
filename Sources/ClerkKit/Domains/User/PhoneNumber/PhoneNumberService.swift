//
//  PhoneNumberService.swift
//  Clerk
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

  @MainActor
  func create(phoneNumber: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers",
      method: .post,
      scopedToActiveSession: true,
      body: ["phone_number": phoneNumber]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func delete(phoneNumberId: String) async throws -> DeletedObject {
    let request = Request<ClientResponse<DeletedObject>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .delete,
      scopedToActiveSession: true
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func prepareVerification(phoneNumberId: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)/prepare_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["strategy": "phone_code"]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func attemptVerification(phoneNumberId: String, code: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)/attempt_verification",
      method: .post,
      scopedToActiveSession: true,
      body: ["code": code]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func makeDefaultSecondFactor(phoneNumberId: String) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["default_second_factor": true]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func setReservedForSecondFactor(phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber {
    let request = Request<ClientResponse<PhoneNumber>>(
      path: "/v1/me/phone_numbers/\(phoneNumberId)",
      method: .patch,
      scopedToActiveSession: true,
      body: ["reserved_for_second_factor": reserved]
    )

    return try await apiClient.send(request).value.response
  }
}
