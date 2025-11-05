//
//  Verification.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

/// The state of the verification process of a sign-in or sign-up attempt.
public struct Verification: Codable, Equatable, Hashable, Sendable {
  /// The state of the verification.
  public var status: Status?

  /// The strategy pertaining to the parent sign-up or sign-in attempt.
  public var strategy: String?

  /// The number of attempts related to the verification.
  public var attempts: Int?

  /// The time the verification will expire at.
  public var expireAt: Date?

  /// The last error the verification attempt ran into.
  public var error: ClerkAPIError?

  /// The redirect URL for an external verification.
  public var externalVerificationRedirectUrl: String?

  /// The nonce pertaining to the verification.
  public var nonce: String?

  public init(
    status: Verification.Status? = nil,
    strategy: String? = nil,
    attempts: Int? = nil,
    expireAt: Date? = nil,
    error: ClerkAPIError? = nil,
    externalVerificationRedirectUrl: String? = nil,
    nonce: String? = nil
  ) {
    self.status = status
    self.strategy = strategy
    self.attempts = attempts
    self.expireAt = expireAt
    self.error = error
    self.externalVerificationRedirectUrl = externalVerificationRedirectUrl
    self.nonce = nonce
  }

  /// The state of the verification.
  public enum Status: String, Codable, Sendable {
    case unverified
    case verified
    case transferable
    case failed
    case expired

    case unknown

    public init(from decoder: Decoder) throws {
      self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
  }
}
