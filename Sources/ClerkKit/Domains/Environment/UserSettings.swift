//
//  UserSettings.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct UserSettings: Codable, Equatable, Sendable {
    public var attributes: [String: AttributesConfig]
    public var signUp: SignUp
    public var social: [String: SocialConfig]
    public var actions: Actions
    public var passkeySettings: PasskeySettings?

    public struct AttributesConfig: Codable, Equatable, Sendable {
      public var enabled: Bool
      public var required: Bool
      public var immutable: Bool?
      public var usedForFirstFactor: Bool
      public var firstFactors: [String]?
      public var usedForSecondFactor: Bool
      public var secondFactors: [String]?
      public var verifications: [String]?
      public var verifyAtSignUp: Bool
    }

    public struct SignUp: Codable, Equatable, Sendable {
      public var customActionRequired: Bool
      public var progressive: Bool
      public var mode: String
      public var legalConsentEnabled: Bool

      public init(
        customActionRequired: Bool = false,
        progressive: Bool = false,
        mode: String = "public",
        legalConsentEnabled: Bool = false
      ) {
        self.customActionRequired = customActionRequired
        self.progressive = progressive
        self.mode = mode
        self.legalConsentEnabled = legalConsentEnabled
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customActionRequired = try container.decodeIfPresent(Bool.self, forKey: .customActionRequired) ?? false
        progressive = try container.decodeIfPresent(Bool.self, forKey: .progressive) ?? false
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "public"
        legalConsentEnabled = try container.decodeIfPresent(Bool.self, forKey: .legalConsentEnabled) ?? false
      }

      enum CodingKeys: String, CodingKey {
        case customActionRequired
        case progressive
        case mode
        case legalConsentEnabled
      }
    }

    public struct SocialConfig: Codable, Equatable, Sendable {
      public var enabled: Bool
      public var required: Bool
      public var authenticatable: Bool
      public var strategy: String
      public var notSelectable: Bool
      public var name: String
      public var logoUrl: String?

      public init(
        enabled: Bool,
        required: Bool,
        authenticatable: Bool,
        strategy: String,
        notSelectable: Bool,
        name: String,
        logoUrl: String? = nil
      ) {
        self.enabled = enabled
        self.required = required
        self.authenticatable = authenticatable
        self.strategy = strategy
        self.notSelectable = notSelectable
        self.name = name
        self.logoUrl = logoUrl
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        authenticatable = try container.decodeIfPresent(Bool.self, forKey: .authenticatable) ?? false
        strategy = try container.decode(String.self, forKey: .strategy)
        notSelectable = try container.decodeIfPresent(Bool.self, forKey: .notSelectable) ?? false
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? strategy
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
      }

      enum CodingKeys: String, CodingKey {
        case enabled
        case required
        case authenticatable
        case strategy
        case notSelectable
        case name
        case logoUrl
      }
    }

    public struct Actions: Codable, Equatable, Sendable {
      public var deleteSelf: Bool = false
      public var createOrganization: Bool = false
    }

    public struct PasskeySettings: Codable, Equatable, Sendable {
      public var allowAutofill: Bool
      public var showSignInButton: Bool
    }
  }
}
