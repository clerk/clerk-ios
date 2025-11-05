//
//  DisplayConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {

  public struct DisplayConfig: Codable, Sendable, Equatable {
    public var instanceEnvironmentType: InstanceEnvironmentType
    public var applicationName: String
    public var preferredSignInStrategy: PreferredSignInStrategy
    public var supportEmail: String?
    public var branded: Bool
    public var logoImageUrl: String
    public var homeUrl: String
    public var privacyPolicyUrl: String?
    public var termsUrl: String?

    public enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable, Sendable, Equatable {
      case password
      case otp
      case unknown

      public init(from decoder: Decoder) throws {
        self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
      }
    }
  }

}

