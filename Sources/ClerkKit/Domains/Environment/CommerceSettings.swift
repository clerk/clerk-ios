//
//  CommerceSettings.swift
//

import Foundation

extension Clerk.Environment {
  public struct CommerceSettings: Codable, Equatable, Sendable {
    public var billing: Billing

    public struct Billing: Codable, Equatable, Sendable {
      public var stripePublishableKey: String?
      public var organization: Payer
      public var user: Payer

      public struct Payer: Codable, Equatable, Sendable {
        public var enabled: Bool
        public var hasPaidPlans: Bool
      }
    }

    /// Sensible defaults when commerce settings are absent from a decoded payload.
    public static let `default` = CommerceSettings(
      billing: Billing(
        stripePublishableKey: nil,
        organization: Billing.Payer(enabled: false, hasPaidPlans: false),
        user: Billing.Payer(enabled: false, hasPaidPlans: false)
      )
    )
  }
}

extension Clerk.Environment.CommerceSettings {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    billing = try container.decodeIfPresent(Billing.self, forKey: .billing) ?? Self.default.billing
  }
}

extension Clerk.Environment.CommerceSettings.Billing {
  public init(from decoder: Decoder) throws {
    let defaults = Clerk.Environment.CommerceSettings.default.billing
    let container = try decoder.container(keyedBy: CodingKeys.self)
    stripePublishableKey = try container.decodeIfPresent(String.self, forKey: .stripePublishableKey)
    organization = try container.decodeIfPresent(Payer.self, forKey: .organization) ?? defaults.organization
    user = try container.decodeIfPresent(Payer.self, forKey: .user) ?? defaults.user
  }
}

extension Clerk.Environment.CommerceSettings.Billing.Payer {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    hasPaidPlans = try container.decodeIfPresent(Bool.self, forKey: .hasPaidPlans) ?? false
  }
}
