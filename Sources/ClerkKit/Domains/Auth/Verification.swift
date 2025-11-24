//
//  Verification.swift
//
//
//  Created by Mike Pitre on 10/26/23.
//

import Foundation

/// The state of the verification process of a sign-in or sign-up attempt.
public struct Verification: Codable, Equatable, Sendable {
  /// The state of the verification.
  public var status: Status?

  /// The strategy pertaining to the parent sign-up or sign-in attempt.
  public var strategy: FactorStrategy?

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
    strategy: FactorStrategy? = nil,
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
  public enum Status: Codable, Sendable, Equatable, Hashable {
    case unverified
    case verified
    case transferable
    case failed
    case expired

    /// Represents an unknown verification status.
    ///
    /// The associated value captures the raw string value from the API.
    case unknown(String)

    /// The raw string value used in the API.
    public var rawValue: String {
      switch self {
      case .unverified:
        "unverified"
      case .verified:
        "verified"
      case .transferable:
        "transferable"
      case .failed:
        "failed"
      case .expired:
        "expired"
      case .unknown(let value):
        value
      }
    }

    /// Creates a `Status` from its raw string value.
    public init(rawValue: String) {
      switch rawValue {
      case "unverified":
        self = .unverified
      case "verified":
        self = .verified
      case "transferable":
        self = .transferable
      case "failed":
        self = .failed
      case "expired":
        self = .expired
      default:
        self = .unknown(rawValue)
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let rawValue = try container.decode(String.self)
      self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(rawValue)
    }
  }
}
