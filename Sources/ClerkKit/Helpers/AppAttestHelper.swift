//
//  AppAttestHelper.swift
//  Clerk
//

import CryptoKit
import DeviceCheck
import Foundation

enum AppAttestHelper {
  private static let keychainKey = ClerkKeychainKey.attestKeyId.rawValue

  @MainActor
  private static var apiClient: APIClient {
    get throws {
      try Clerk.currentDependencies.apiClient
    }
  }

  @MainActor
  private static var keychain: any KeychainStorage {
    get throws {
      try Clerk.currentDependencies.appLocalKeychain
    }
  }

  enum AttestationError: Error {
    case unsupportedDevice
    case unableToGetChallengeFromServer
    case unableToFormatChallengeAsData
  }

  /// Retrieves a challenge from the server for attestation.
  /// - Returns: A challenge string received from the server.
  /// - Throws: `AttestationError.unableToGetChallengeFromServer` if the challenge cannot be retrieved.
  @MainActor
  private static func getChallenge() async throws -> String {
    let request = Request<[String: String]>(
      path: "/v1/client/device_attestation/challenges",
      method: .post
    )

    let response = try await apiClient.send(request).value

    guard let challenge = response["challenge"] else {
      throw AttestationError.unableToGetChallengeFromServer
    }

    return challenge
  }

  @discardableResult
  @MainActor
  static func performDeviceAttestation() async throws -> String {
    guard DCAppAttestService.shared.isSupported else {
      throw AttestationError.unsupportedDevice
    }

    let challenge = try await getChallenge()
    let keyId = try await DCAppAttestService.shared.generateKey()

    guard let challengeData = challenge.data(using: .utf8) else {
      throw AttestationError.unableToFormatChallengeAsData
    }

    let clientDataHash = Data(SHA256.hash(data: challengeData))
    let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash)
    try await verify(keyId: keyId, challenge: challenge, attestation: attestation)

    try keychain.set(keyId, forKey: keychainKey)
    return keyId
  }

  @MainActor
  private static func verify(keyId: String, challenge: String, attestation: Data) async throws {
    let body = [
      "key_id": keyId,
      "challenge": challenge,
      "attestation": attestation.base64EncodedString(),
      "bundle_id": Bundle.main.bundleIdentifier,
    ]

    let request = Request<EmptyResponse>(
      path: "/v1/client/device_attestation/verify",
      method: .post,
      body: body
    )

    try await apiClient.send(request)
  }

  @MainActor
  private static func createAssertion(payload: Data) async throws -> String {
    let keyId: String = if let existingKeyId = Self.keyId {
      existingKeyId
    } else {
      try await performDeviceAttestation()
    }

    let hash = Data(SHA256.hash(data: payload))
    let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: hash)
    return assertion.base64EncodedString()
  }

  @MainActor
  static func performAssertion() async throws {
    guard DCAppAttestService.shared.isSupported else {
      throw AttestationError.unsupportedDevice
    }

    let challenge = try await getChallenge()
    guard let clientId = Clerk.shared.identityController.persistedClientID() else {
      throw ClerkClientError(message: "Client ID is unavailable.", localizationBundle: .module)
    }
    let payload = try JSONEncoder().encode(["client_id": clientId, "challenge": challenge])
    let assertion = try await createAssertion(payload: payload)

    let body = [
      "client_data": String(bytes: payload, encoding: .utf8) ?? "",
      "assertion": assertion,
      "challenge": challenge,
      "platform": "ios",
      "bundle_id": Bundle.main.bundleIdentifier,
    ]

    let request = Request<EmptyResponse>(
      path: "/v1/client/verify",
      method: .post,
      body: body
    )

    try await apiClient.send(request)
  }

  @MainActor
  static var hasKeyId: Bool {
    do {
      return try keychain.hasItem(forKey: keychainKey)
    } catch {
      return false
    }
  }

  @MainActor
  private static var keyId: String? {
    try? keychain.string(forKey: keychainKey)
  }

  @MainActor
  static func removeKeyId() throws {
    try keychain.deleteItem(forKey: keychainKey)
  }
}
