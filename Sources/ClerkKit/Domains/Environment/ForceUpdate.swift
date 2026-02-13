//
//  ForceUpdate.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct ForceUpdate: Codable, Sendable, Equatable {
    public var ios: [IOSPolicy]
    public var android: [AndroidPolicy]

    enum CodingKeys: String, CodingKey {
      case ios
      case android
    }

    public init(
      ios: [IOSPolicy] = [],
      android: [AndroidPolicy] = []
    ) {
      self.ios = ios
      self.android = android
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      ios = try container.decodeIfPresent([IOSPolicy].self, forKey: .ios) ?? []
      android = try container.decodeIfPresent([AndroidPolicy].self, forKey: .android) ?? []
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

    public struct AndroidPolicy: Codable, Sendable, Equatable {
      public var packageName: String
      public var minimumVersion: String
      public var updateUrl: String?

      public init(
        packageName: String,
        minimumVersion: String,
        updateUrl: String? = nil
      ) {
        self.packageName = packageName
        self.minimumVersion = minimumVersion
        self.updateUrl = updateUrl
      }
    }
  }
}
