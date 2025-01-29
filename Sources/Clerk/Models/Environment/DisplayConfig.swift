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
        let captchaPublicKey: String?
        let captchaWidgetType: CaptchaWidgetType?
        let captchaPublicKeyInvisible: String?
        let captchaProvider: CaptchaProvider?
        
        enum InstanceEnvironmentType: String, Codable, CodingKeyRepresentable, Sendable {
            case production
            case development
            case unknown
            
            init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        enum PreferredSignInStrategy: String, Codable, CodingKeyRepresentable, Sendable {
            case password
            case otp
            case unknown
            
            init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        enum CaptchaWidgetType: String, Codable, CodingKeyRepresentable, Sendable {
            case invisible
            case smart
            case unknown
            
            init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
        
        enum CaptchaProvider: String, Codable, CodingKeyRepresentable, Sendable {
            case turnstile
            case unknown
            
            init(from decoder: Decoder) throws {
                self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
            }
        }
    }
    
}
