//
//  DisplayConfig.swift
//  Clerk
//
//  Created by Mike Pitre on 8/2/24.
//

import Foundation

extension Clerk.Environment {
    
    public struct DisplayConfig: Codable, Sendable {
        public let applicationName: String
        public let preferredSignInStrategy: PreferredSignInStrategy
        public let branded: Bool
        public let logoImageUrl: String
        public let homeUrl: String
        public let captchaPublicKey: String?
        public let captchaWidgetType: CaptchaWidgetType?
        public let captchaPublicKeyInvisible: String?
        public let captchaProvider: CaptchaProvider?
        
        public enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable, Sendable {
            case password
            case otp
            case unknown
            
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        public enum CaptchaWidgetType: String, Codable, CodingKeyRepresentable, Sendable {
            case invisible
            case smart
            case unknown
            
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        public enum CaptchaProvider: String, Codable, CodingKeyRepresentable, Sendable {
            case turnstile
            case unknown
            
            public init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
    }
    
}

extension Clerk.Environment.DisplayConfig {
    
    public var botProtectionIsEnabled: Bool {
        captchaWidgetType != nil
    }
    
}
