//
//  UserSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
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
    }

    public struct SocialConfig: Codable, Equatable, Sendable {
      public var enabled: Bool
      public var required: Bool
      public var authenticatable: Bool
      public var strategy: String
      public var notSelectable: Bool
      public var name: String
      public var logoUrl: String?
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
