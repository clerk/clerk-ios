//
//  SessionVerification.swift
//

import Foundation

/// Represents the state of an in-session reverification (step-up) flow.
///
/// Use ``Session/startVerification(level:)`` to begin a reverification, then complete it
/// with the appropriate first- or second-factor convenience method (for example,
/// ``Session/verifyWithPassword(_:)``, ``Session/verifyWithPasskey()``, or
/// ``Session/verifyWithTOTP(code:)``). When the verification completes successfully the
/// associated session's first-factor age is refreshed, allowing subsequent calls that
/// require step-up to succeed without forcing the user to sign out and back in.
public struct SessionVerification: Codable, Equatable, Sendable {
  /// The unique identifier for the verification attempt.
  public var id: String?

  /// The current status of the verification.
  public var status: Status

  /// The required verification level.
  public var level: Level

  /// The session associated with the verification.
  public var session: Session?

  /// First factors supported for this verification.
  public var supportedFirstFactors: [Factor]?

  /// Second factors supported for this verification.
  public var supportedSecondFactors: [Factor]?

  /// The state of the first-factor verification.
  public var firstFactorVerification: Verification?

  /// The state of the second-factor verification.
  public var secondFactorVerification: Verification?

  public init(
    id: String? = nil,
    status: Status,
    level: Level,
    session: Session? = nil,
    supportedFirstFactors: [Factor]? = nil,
    supportedSecondFactors: [Factor]? = nil,
    firstFactorVerification: Verification? = nil,
    secondFactorVerification: Verification? = nil
  ) {
    self.id = id
    self.status = status
    self.level = level
    self.session = session
    self.supportedFirstFactors = supportedFirstFactors
    self.supportedSecondFactors = supportedSecondFactors
    self.firstFactorVerification = firstFactorVerification
    self.secondFactorVerification = secondFactorVerification
  }

  /// The status of a session verification attempt.
  public enum Status: Codable, Sendable, Equatable, Hashable {
    /// The first factor still needs to be verified.
    case needsFirstFactor

    /// The first factor is verified but a second factor is required.
    case needsSecondFactor

    /// The verification completed successfully.
    case complete

    /// Represents an unknown status, capturing the raw value for forward compatibility.
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .needsFirstFactor:
        "needs_first_factor"
      case .needsSecondFactor:
        "needs_second_factor"
      case .complete:
        "complete"
      case .unknown(let value):
        value
      }
    }

    public init(rawValue: String) {
      switch rawValue {
      case "needs_first_factor":
        self = .needsFirstFactor
      case "needs_second_factor":
        self = .needsSecondFactor
      case "complete":
        self = .complete
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

  /// The required level of verification.
  public enum Level: Codable, Sendable, Equatable, Hashable {
    /// Only a first factor is required (for example a password or passkey).
    case firstFactor

    /// Only a second factor is required (for example TOTP).
    case secondFactor

    /// Both a first and second factor are required.
    case multiFactor

    /// Represents an unknown level, capturing the raw value for forward compatibility.
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .firstFactor:
        "first_factor"
      case .secondFactor:
        "second_factor"
      case .multiFactor:
        "multi_factor"
      case .unknown(let value):
        value
      }
    }

    public init(rawValue: String) {
      switch rawValue {
      case "first_factor":
        self = .firstFactor
      case "second_factor":
        self = .secondFactor
      case "multi_factor":
        self = .multiFactor
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
