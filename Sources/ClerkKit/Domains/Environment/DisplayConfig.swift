//
//  DisplayConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

public extension Clerk.Environment {
  struct DisplayConfig: Codable, Sendable, Equatable {
    public var instanceEnvironmentType: InstanceEnvironmentType
    public var applicationName: String
    public var preferredSignInStrategy: PreferredSignInStrategy
    public var supportEmail: String?
    public var branded: Bool
    public var logoImageUrl: String
    public var homeUrl: String
    public var privacyPolicyUrl: String?
    public var termsUrl: String?

    public enum PreferredSignInStrategy: Codable, Sendable, Equatable {
      case password
      case otp

      /// Represents an unknown preferred sign-in strategy.
      ///
      /// The associated value captures the raw string value from the API.
      case unknown(String)

      /// The raw string value used in the API.
      public var rawValue: String {
        switch self {
        case .password:
          "password"
        case .otp:
          "otp"
        case .unknown(let value):
          value
        }
      }

      /// Creates a `PreferredSignInStrategy` from its raw string value.
      public init(rawValue: String) {
        switch rawValue {
        case "password":
          self = .password
        case "otp":
          self = .otp
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
}
