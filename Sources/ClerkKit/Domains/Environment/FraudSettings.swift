//
//  FraudSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 2/3/25.
//

import Foundation

extension Clerk.Environment {
  public struct FraudSettings: Codable, Sendable, Equatable {
    public let native: Native

    public struct Native: Codable, Sendable, Equatable {
      public let deviceAttestationMode: DeviceAttestationMode

      public enum DeviceAttestationMode: Codable, Sendable, Equatable {
        case disabled
        case onboarding
        case enforced

        /// Represents an unknown device attestation mode.
        ///
        /// The associated value captures the raw string value from the API.
        case unknown(String)

        /// The raw string value used in the API.
        public var rawValue: String {
          switch self {
          case .disabled:
            "disabled"
          case .onboarding:
            "onboarding"
          case .enforced:
            "enforced"
          case .unknown(let value):
            value
          }
        }

        /// Creates a `DeviceAttestationMode` from its raw string value.
        public init(rawValue: String) {
          switch rawValue {
          case "disabled":
            self = .disabled
          case "onboarding":
            self = .onboarding
          case "enforced":
            self = .enforced
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
}
