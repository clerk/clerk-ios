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
  init(apiClient _: APIClient) {}

  @MainActor
  func list() async throws -> [BiometricCredential] {
    try await Clerk.js(.clerk, JSRawCall("listNativeBiometricCredentials"), as: [BiometricCredential].self)
  }

  @MainActor
  func prepareEnrollment(sessionId: String, params: BiometricCredential.PrepareEnrollmentParams) async throws -> BiometricCredentialChallenge {
    try await Clerk.js(.clerk, JSRawCall("prepareNativeBiometricEnrollment", .string(sessionId), JSONValue(encoding: params)), as: BiometricCredentialChallenge.self)
  }

  @MainActor
  func attemptEnrollment(sessionId: String, params: BiometricCredential.AttemptEnrollmentParams) async throws -> BiometricCredential {
    try await Clerk.js(.clerk, JSRawCall("attemptNativeBiometricEnrollment", .string(sessionId), JSONValue(encoding: params)), as: BiometricCredential.self)
  }

  @MainActor
  func validateSignInCredential(biometricCredentialId: String) async throws -> BiometricCredentialValidation {
    try await Clerk.js(.clerk, JSRawCall("validateNativeBiometricCredential", .string(biometricCredentialId)), as: BiometricCredentialValidation.self)
  }

  @MainActor
  func revoke(biometricCredentialId: String, sessionId: String?) async throws -> BiometricCredential {
    try await Clerk.js(.clerk, JSRawCall("revokeNativeBiometricCredential", .string(biometricCredentialId), sessionId.map(JSONValue.string) ?? .null), as: BiometricCredential.self)
  }
}
