//
//  BiometricCredential.swift
//  Clerk
//

import Foundation

/// A biometric credential associated with a user.
public struct BiometricCredential: Codable, Identifiable, Equatable, Sendable {
  /// The unique identifier of the biometric credential.
  public var id: String

  /// The resource object name.
  public var object: String

  /// The platform this credential belongs to.
  public var platform: Platform

  /// The native app identifier this credential is bound to.
  public var appIdentifier: String

  /// The user-facing credential name.
  public var name: String?

  /// The signature algorithm used by the credential.
  public var algorithm: Algorithm

  /// The credential status.
  public var status: Status

  /// The date when the credential was created.
  public var createdAt: Date

  /// The date when the credential was last updated.
  public var updatedAt: Date

  /// The date when the credential was last used.
  public var lastUsedAt: Date?

  /// The date when the credential was revoked.
  public var revokedAt: Date?

  public init(
    id: String,
    object: String = "trusted_device",
    platform: Platform,
    appIdentifier: String,
    name: String? = nil,
    algorithm: Algorithm,
    status: Status,
    createdAt: Date,
    updatedAt: Date,
    lastUsedAt: Date? = nil,
    revokedAt: Date? = nil
  ) {
    self.id = id
    self.object = object
    self.platform = platform
    self.appIdentifier = appIdentifier
    self.name = name
    self.algorithm = algorithm
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.lastUsedAt = lastUsedAt
    self.revokedAt = revokedAt
  }
}

extension BiometricCredential {
  /// The platform a biometric credential belongs to.
  public enum Platform: Codable, Equatable, Hashable, Sendable {
    case iOS
    case android
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .iOS:
        "ios"
      case .android:
        "android"
      case let .unknown(value):
        value
      }
    }

    public init(rawValue: String) {
      switch rawValue {
      case "ios":
        self = .iOS
      case "android":
        self = .android
      default:
        self = .unknown(rawValue)
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      try self.init(rawValue: container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(rawValue)
    }
  }

  /// The credential signing algorithm.
  public enum Algorithm: Codable, Equatable, Hashable, Sendable {
    case es256
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .es256:
        "ES256"
      case let .unknown(value):
        value
      }
    }

    public init(rawValue: String) {
      switch rawValue {
      case "ES256":
        self = .es256
      default:
        self = .unknown(rawValue)
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      try self.init(rawValue: container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(rawValue)
    }
  }

  /// The server-side biometric credential status.
  public enum Status: Codable, Equatable, Hashable, Sendable {
    case active
    case revoked
    case unknown(String)

    public var rawValue: String {
      switch self {
      case .active:
        "active"
      case .revoked:
        "revoked"
      case let .unknown(value):
        value
      }
    }

    public init(rawValue: String) {
      switch rawValue {
      case "active":
        self = .active
      case "revoked":
        self = .revoked
      default:
        self = .unknown(rawValue)
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      try self.init(rawValue: container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(rawValue)
    }
  }
}
