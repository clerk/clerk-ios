//
//  FraudSettings.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct FraudSettings: Codable, Sendable, Equatable {
    public let native: Native

    public init(native: Native = .init()) {
      self.native = native
    }

    private enum CodingKeys: String, CodingKey {
      case native
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      native = try container.decodeIfPresent(Native.self, forKey: .native) ?? .init()
    }

    public struct Native: Codable, Sendable, Equatable {
      public let deviceAttestationMode: DeviceAttestationMode

      public init(deviceAttestationMode: DeviceAttestationMode = .disabled) {
        self.deviceAttestationMode = deviceAttestationMode
      }

      private enum CodingKeys: String, CodingKey {
        case deviceAttestationMode
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceAttestationMode =
          try container.decodeIfPresent(DeviceAttestationMode.self, forKey: .deviceAttestationMode) ?? .disabled
      }

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
