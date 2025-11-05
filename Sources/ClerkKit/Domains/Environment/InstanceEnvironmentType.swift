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
public enum InstanceEnvironmentType: String, Codable, CodingKeyRepresentable, Sendable {
  /// Represents a production environment.
  case production

  /// Represents a development environment.
  case development

  /// Represents an unknown environment.
  ///
  /// Used as a fallback in case of decoding error.
  case unknown

  public init(from decoder: Decoder) throws {
    self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
  }
}
