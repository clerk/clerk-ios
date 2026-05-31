//
//  DisplayConfig.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct DisplayConfig: Codable, Sendable, Equatable {
    public var instanceEnvironmentType: InstanceEnvironmentType
    public var applicationName: String
    public var preferredSignInStrategy: PreferredSignInStrategy
    public var supportEmail: String?
    public var showDevmodeWarning: Bool
    public var branded: Bool
    public var logoImageUrl: String
    public var homeUrl: String
    public var privacyPolicyUrl: String?
    public var termsUrl: String?

    public init(
      instanceEnvironmentType: InstanceEnvironmentType,
      applicationName: String,
      preferredSignInStrategy: PreferredSignInStrategy,
      supportEmail: String?,
      showDevmodeWarning: Bool,
      branded: Bool,
      logoImageUrl: String,
      homeUrl: String,
      privacyPolicyUrl: String?,
      termsUrl: String?
    ) {
      self.instanceEnvironmentType = instanceEnvironmentType
      self.applicationName = applicationName
      self.preferredSignInStrategy = preferredSignInStrategy
      self.supportEmail = supportEmail
      self.showDevmodeWarning = showDevmodeWarning
      self.branded = branded
      self.logoImageUrl = logoImageUrl
      self.homeUrl = homeUrl
      self.privacyPolicyUrl = privacyPolicyUrl
      self.termsUrl = termsUrl
    }

    enum CodingKeys: CodingKey {
      case instanceEnvironmentType
      case applicationName
      case preferredSignInStrategy
      case supportEmail
      case showDevmodeWarning
      case branded
      case logoImageUrl
      case homeUrl
      case privacyPolicyUrl
      case termsUrl
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      instanceEnvironmentType = try container.decode(InstanceEnvironmentType.self, forKey: .instanceEnvironmentType)
      applicationName = try container.decode(String.self, forKey: .applicationName)
      preferredSignInStrategy = try container.decode(PreferredSignInStrategy.self, forKey: .preferredSignInStrategy)
      supportEmail = try container.decodeIfPresent(String.self, forKey: .supportEmail)
      showDevmodeWarning = try container.decodeIfPresent(Bool.self, forKey: .showDevmodeWarning) ?? false
      branded = try container.decode(Bool.self, forKey: .branded)
      logoImageUrl = try container.decode(String.self, forKey: .logoImageUrl)
      homeUrl = try container.decode(String.self, forKey: .homeUrl)
      privacyPolicyUrl = try container.decodeIfPresent(String.self, forKey: .privacyPolicyUrl)
      termsUrl = try container.decodeIfPresent(String.self, forKey: .termsUrl)
    }

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
