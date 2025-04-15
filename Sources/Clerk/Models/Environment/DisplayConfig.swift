//
//  DisplayConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {

  struct DisplayConfig: Codable, Sendable {
    let instanceEnvironmentType: InstanceEnvironmentType
    let applicationName: String
    let preferredSignInStrategy: PreferredSignInStrategy
    let branded: Bool
    let logoImageUrl: String
    let homeUrl: String
    let privacyPolicyUrl: String?
    let termsUrl: String?

    enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable, Sendable {
      case password
      case otp
      case unknown

      init(from decoder: Decoder) throws {
        self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
      }
    }
  }

}

extension Clerk.Environment.DisplayConfig {
  
  static var mock: Self {
    .init(
      instanceEnvironmentType: .development,
      applicationName: "Acme Co",
      preferredSignInStrategy: .otp,
      branded: true,
      logoImageUrl: "",
      homeUrl: "",
      privacyPolicyUrl: "privacy",
      termsUrl: "terms"
    )
  }
  
}
