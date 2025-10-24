//
//  DisplayConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {

    public struct DisplayConfig: Codable, Sendable, Equatable {
        public let instanceEnvironmentType: InstanceEnvironmentType
        public let applicationName: String
        public let preferredSignInStrategy: PreferredSignInStrategy
        public let supportEmail: String?
        public let branded: Bool
        public let logoImageUrl: String
        public let homeUrl: String
        public let privacyPolicyUrl: String?
        public let termsUrl: String?

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

extension Clerk.Environment.DisplayConfig {

    package static var mock: Self {
        .init(
            instanceEnvironmentType: .development,
            applicationName: "Acme Co",
            preferredSignInStrategy: .otp,
            supportEmail: "support@example.com",
            branded: true,
            logoImageUrl: "",
            homeUrl: "",
            privacyPolicyUrl: "privacy",
            termsUrl: "terms"
        )
    }

}
