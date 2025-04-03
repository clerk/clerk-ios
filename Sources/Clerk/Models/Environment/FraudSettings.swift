//
//  FraudSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 2/3/25.
//

import Foundation

extension Clerk.Environment {

  struct FraudSettings: Codable, Sendable {

    let native: Native

    struct Native: Codable, Sendable {

      let deviceAttestationMode: DeviceAttestationMode

      enum DeviceAttestationMode: String, Codable, CodingKeyRepresentable, Sendable {
        case disabled
        case onboarding
        case enforced
        case unknown

        public init(from decoder: Decoder) throws {
          self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
      }
    }
  }
}
