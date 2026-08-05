//
//  TrustedDeviceChallenge.swift
//  Clerk
//

import Foundation

/// A server challenge for trusted-device enrollment or sign-in.
public struct TrustedDeviceChallenge: Codable, Equatable, Hashable, Sendable {
  /// The resource object name.
  public var object: String

  /// The challenge value.
  public var challenge: String

  /// The unique identifier of the challenge.
  public var challengeId: String

  /// The trusted-device credential ID for sign-in challenges.
  public var trustedDeviceId: String?

  /// The exact client data string that must be signed.
  public var clientData: String

  /// The date when the challenge expires.
  public var expiresAt: Date

  /// The signature algorithm required for the challenge.
  public var algorithm: TrustedDevice.Algorithm

  public init(
    object: String = "trusted_device_challenge",
    challenge: String,
    challengeId: String,
    trustedDeviceId: String? = nil,
    clientData: String,
    expiresAt: Date,
    algorithm: TrustedDevice.Algorithm
  ) {
    self.object = object
    self.challenge = challenge
    self.challengeId = challengeId
    self.trustedDeviceId = trustedDeviceId
    self.clientData = clientData
    self.expiresAt = expiresAt
    self.algorithm = algorithm
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    object = try container.decode(String.self, forKey: .object)
    challenge = try container.decode(String.self, forKey: .challenge)
    challengeId = try container.decode(String.self, forKey: .challengeId)
    trustedDeviceId = try container.decodeIfPresent(String.self, forKey: .trustedDeviceId)
    clientData = try container.decode(String.self, forKey: .clientData)
    algorithm = try container.decode(TrustedDevice.Algorithm.self, forKey: .algorithm)

    let rawExpiresAt = try container.decode(Double.self, forKey: .expiresAt)
    expiresAt = Date(timeIntervalSince1970: rawExpiresAt > 10_000_000_000 ? rawExpiresAt / 1000 : rawExpiresAt)
  }
}
