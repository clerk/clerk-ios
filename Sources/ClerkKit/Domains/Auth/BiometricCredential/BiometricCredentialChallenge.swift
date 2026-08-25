//
//  BiometricCredentialChallenge.swift
//  Clerk
//

import Foundation

/// A server challenge for biometric credential enrollment or sign-in.
public struct BiometricCredentialChallenge: Codable, Equatable, Hashable, Sendable {
  /// The resource object name.
  public var object: String

  /// The challenge value.
  public var challenge: String

  /// The unique identifier of the challenge.
  public var challengeId: String

  /// The biometric credential ID for sign-in challenges.
  public var biometricCredentialId: String?

  /// The exact client data string that must be signed.
  public var clientData: String

  /// The date when the challenge expires.
  public var expiresAt: Date

  /// The signature algorithm required for the challenge.
  public var algorithm: BiometricCredential.Algorithm

  private enum CodingKeys: String, CodingKey {
    case object
    case challenge
    case challengeId
    case biometricCredentialId = "trustedDeviceId"
    case clientData
    case expiresAt
    case algorithm
  }

  public init(
    object: String = "trusted_device_challenge",
    challenge: String,
    challengeId: String,
    biometricCredentialId: String? = nil,
    clientData: String,
    expiresAt: Date,
    algorithm: BiometricCredential.Algorithm
  ) {
    self.object = object
    self.challenge = challenge
    self.challengeId = challengeId
    self.biometricCredentialId = biometricCredentialId
    self.clientData = clientData
    self.expiresAt = expiresAt
    self.algorithm = algorithm
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    object = try container.decode(String.self, forKey: .object)
    challenge = try container.decode(String.self, forKey: .challenge)
    challengeId = try container.decode(String.self, forKey: .challengeId)
    biometricCredentialId = try container.decodeIfPresent(String.self, forKey: .biometricCredentialId)
    clientData = try container.decode(String.self, forKey: .clientData)
    algorithm = try container.decode(BiometricCredential.Algorithm.self, forKey: .algorithm)

    let rawExpiresAt = try container.decode(Double.self, forKey: .expiresAt)
    expiresAt = Date(timeIntervalSince1970: rawExpiresAt > 10_000_000_000 ? rawExpiresAt / 1000 : rawExpiresAt)
  }
}
