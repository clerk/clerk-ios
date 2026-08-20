//
//  MockBiometricCredentialService.swift
//  Clerk
//

import Foundation

package final class MockBiometricCredentialService: BiometricCredentialServiceProtocol {
  package nonisolated(unsafe) var listHandler: (() async throws -> [BiometricCredential])?
  package nonisolated(unsafe) var prepareEnrollmentHandler: ((String, BiometricCredential.PrepareEnrollmentParams) async throws -> BiometricCredentialChallenge)?
  package nonisolated(unsafe) var attemptEnrollmentHandler: ((String, BiometricCredential.AttemptEnrollmentParams) async throws -> BiometricCredential)?
  package nonisolated(unsafe) var validateSignInCredentialHandler: ((String) async throws -> BiometricCredentialValidation)?
  package nonisolated(unsafe) var revokeHandler: ((String, String?) async throws -> BiometricCredential)?

  package init(
    list: (() async throws -> [BiometricCredential])? = nil,
    prepareEnrollment: ((String, BiometricCredential.PrepareEnrollmentParams) async throws -> BiometricCredentialChallenge)? = nil,
    attemptEnrollment: ((String, BiometricCredential.AttemptEnrollmentParams) async throws -> BiometricCredential)? = nil,
    validateSignInCredential: ((String) async throws -> BiometricCredentialValidation)? = nil,
    revoke: ((String, String?) async throws -> BiometricCredential)? = nil
  ) {
    listHandler = list
    prepareEnrollmentHandler = prepareEnrollment
    attemptEnrollmentHandler = attemptEnrollment
    validateSignInCredentialHandler = validateSignInCredential
    revokeHandler = revoke
  }

  @MainActor
  package func list() async throws -> [BiometricCredential] {
    if let handler = listHandler {
      return try await handler()
    }
    return [.mock]
  }

  @MainActor
  package func prepareEnrollment(
    sessionId: String,
    params: BiometricCredential.PrepareEnrollmentParams
  ) async throws -> BiometricCredentialChallenge {
    if let handler = prepareEnrollmentHandler {
      return try await handler(sessionId, params)
    }
    return .mock
  }

  @MainActor
  package func attemptEnrollment(
    sessionId: String,
    params: BiometricCredential.AttemptEnrollmentParams
  ) async throws -> BiometricCredential {
    if let handler = attemptEnrollmentHandler {
      return try await handler(sessionId, params)
    }
    return .mock
  }

  @MainActor
  package func validateSignInCredential(biometricCredentialId: String) async throws -> BiometricCredentialValidation {
    if let handler = validateSignInCredentialHandler {
      return try await handler(biometricCredentialId)
    }
    return .init(valid: true)
  }

  @MainActor
  package func revoke(
    biometricCredentialId: String,
    sessionId: String?
  ) async throws -> BiometricCredential {
    if let handler = revokeHandler {
      return try await handler(biometricCredentialId, sessionId)
    }
    return .mock
  }
}
