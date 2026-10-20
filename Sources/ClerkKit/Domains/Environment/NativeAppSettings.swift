//
//  NativeAppSettings.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  /// Settings for native apps registered in the Clerk Dashboard.
  public struct NativeAppSettings: Codable, Sendable, Equatable {
    /// The minimum app version each registered app must run.
    public var minimumSupportedVersion: MinimumSupportedVersion

    enum CodingKeys: String, CodingKey {
      case minimumSupportedVersion
    }

    public init(minimumSupportedVersion: MinimumSupportedVersion = .init()) {
      self.minimumSupportedVersion = minimumSupportedVersion
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      minimumSupportedVersion = try container.decodeIfPresent(
        MinimumSupportedVersion.self,
        forKey: .minimumSupportedVersion
      ) ?? .init()
    }

    /// Settings with no minimum versions, used when native app settings are absent from a decoded payload.
    public static let `default` = NativeAppSettings()
  }

  /// The minimum app versions set in the Clerk Dashboard, by platform.
  public struct MinimumSupportedVersion: Codable, Sendable, Equatable {
    /// The minimum version of each iOS app, by bundle ID.
    public var ios: [IOSPolicy]

    enum CodingKeys: String, CodingKey {
      case ios
    }

    public init(ios: [IOSPolicy] = []) {
      self.ios = ios
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      ios = try (container.decodeIfPresent([DecodedIfValid<IOSPolicy>].self, forKey: .ios) ?? []).compactMap(\.value)
    }

    /// The minimum version of one iOS app.
    public struct IOSPolicy: Codable, Sendable, Equatable {
      /// The app's bundle ID.
      public var bundleId: String

      /// The oldest supported `CFBundleShortVersionString`.
      public var minimumVersion: String

      /// The App Store page to send users to so they can update.
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

private struct DecodedIfValid<Value: Decodable>: Decodable {
  let value: Value?

  init(from decoder: Decoder) throws {
    value = try? Value(from: decoder)
  }
}
