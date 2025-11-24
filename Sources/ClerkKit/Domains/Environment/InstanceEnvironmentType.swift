//
//  InstanceEnvironmentType.swift
//  Clerk
//
//  Created by Mike Pitre on 1/27/25.
//

/// An enumeration representing the type of environment for an instance.
///
/// This is used to distinguish between production and development environments, allowing for
/// environment-specific behavior or configurations.
public enum InstanceEnvironmentType: Codable, Sendable, Equatable {
  /// Represents a production environment.
  case production

  /// Represents a development environment.
  case development

  /// Represents an unknown environment.
  ///
  /// Used as a fallback in case of decoding error. The associated value captures the raw string value from the API.
  case unknown(String)

  /// The raw string value used in the API.
  public var rawValue: String {
    switch self {
    case .production:
      "production"
    case .development:
      "development"
    case .unknown(let value):
      value
    }
  }

  /// Creates an `InstanceEnvironmentType` from its raw string value.
  public init(rawValue: String) {
    switch rawValue {
    case "production":
      self = .production
    case "development":
      self = .development
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
