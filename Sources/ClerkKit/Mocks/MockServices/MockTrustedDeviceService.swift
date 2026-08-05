//
//  MockTrustedDeviceService.swift
//  Clerk
//

import Foundation

package final class MockTrustedDeviceService: TrustedDeviceServiceProtocol {
  package nonisolated(unsafe) var listHandler: (() async throws -> [TrustedDevice])?
  package nonisolated(unsafe) var prepareEnrollmentHandler: ((String, TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge)?
  package nonisolated(unsafe) var attemptEnrollmentHandler: ((String, TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice)?
  package nonisolated(unsafe) var validateSignInCredentialHandler: ((String) async throws -> TrustedDeviceValidation)?
  package nonisolated(unsafe) var revokeHandler: ((String, String?) async throws -> TrustedDevice)?

  package init(
    list: (() async throws -> [TrustedDevice])? = nil,
    prepareEnrollment: ((String, TrustedDevice.PrepareEnrollmentParams) async throws -> TrustedDeviceChallenge)? = nil,
    attemptEnrollment: ((String, TrustedDevice.AttemptEnrollmentParams) async throws -> TrustedDevice)? = nil,
    validateSignInCredential: ((String) async throws -> TrustedDeviceValidation)? = nil,
    revoke: ((String, String?) async throws -> TrustedDevice)? = nil
  ) {
    listHandler = list
    prepareEnrollmentHandler = prepareEnrollment
    attemptEnrollmentHandler = attemptEnrollment
    validateSignInCredentialHandler = validateSignInCredential
    revokeHandler = revoke
  }

  @MainActor
  package func list() async throws -> [TrustedDevice] {
    if let handler = listHandler {
      return try await handler()
    }
    return [.mock]
  }

  @MainActor
  package func prepareEnrollment(
    sessionId: String,
    params: TrustedDevice.PrepareEnrollmentParams
  ) async throws -> TrustedDeviceChallenge {
    if let handler = prepareEnrollmentHandler {
      return try await handler(sessionId, params)
    }
    return .mock
  }

  @MainActor
  package func attemptEnrollment(
    sessionId: String,
    params: TrustedDevice.AttemptEnrollmentParams
  ) async throws -> TrustedDevice {
    if let handler = attemptEnrollmentHandler {
      return try await handler(sessionId, params)
    }
    return .mock
  }

  @MainActor
  package func validateSignInCredential(trustedDeviceId: String) async throws -> TrustedDeviceValidation {
    if let handler = validateSignInCredentialHandler {
      return try await handler(trustedDeviceId)
    }
    return .init(valid: true)
  }

  @MainActor
  package func revoke(
    trustedDeviceId: String,
    sessionId: String?
  ) async throws -> TrustedDevice {
    if let handler = revokeHandler {
      return try await handler(trustedDeviceId, sessionId)
    }
    return .mock
  }
}
