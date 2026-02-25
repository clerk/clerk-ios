//
//  NativeAppSettings.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct NativeAppSettings: Codable, Sendable, Equatable {
    public var minimumSupportedVersion: MinimumSupportedVersion

    public init(
      minimumSupportedVersion: MinimumSupportedVersion = .init()
    ) {
      self.minimumSupportedVersion = minimumSupportedVersion
    }
  }

  public struct MinimumSupportedVersion: Codable, Sendable, Equatable {
    public var ios: [IOSPolicy]

    enum CodingKeys: String, CodingKey {
      case ios
    }

    public init(
      ios: [IOSPolicy] = []
    ) {
      self.ios = ios
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      ios = try container.decodeIfPresent([IOSPolicy].self, forKey: .ios) ?? []
    }

    public struct IOSPolicy: Codable, Sendable, Equatable {
      public var bundleId: String
      public var minimumVersion: String
      public var updateUrl: String?

      public init(
        bundleId: String,
        minimumVersion: String,
        updateUrl: String? = nil
      ) {
        self.bundleId = bundleId
        self.minimumVersion = minimumVersion
        self.updateUrl = updateUrl
      }
    }

  }
}
