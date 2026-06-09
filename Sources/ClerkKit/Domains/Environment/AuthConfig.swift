//
//  AuthConfig.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct AuthConfig: Codable, Sendable, Equatable {
    public var singleSessionMode: Bool
    public var nativeSettings: NativeSettings

    public init(
      singleSessionMode: Bool,
      nativeSettings: NativeSettings = .default
    ) {
      self.singleSessionMode = singleSessionMode
      self.nativeSettings = nativeSettings
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      singleSessionMode = try container.decode(Bool.self, forKey: .singleSessionMode)
      nativeSettings = try container.decodeIfPresent(NativeSettings.self, forKey: .nativeSettings) ?? .default
    }
  }
}

extension Clerk.Environment.AuthConfig {
  public struct NativeSettings: Codable, Sendable, Equatable {
    public var apiEnabled: Bool
    public var trustedDeviceSignInEnabled: Bool

    public static let `default` = NativeSettings(
      apiEnabled: false,
      trustedDeviceSignInEnabled: false
    )

    public init(
      apiEnabled: Bool,
      trustedDeviceSignInEnabled: Bool
    ) {
      self.apiEnabled = apiEnabled
      self.trustedDeviceSignInEnabled = trustedDeviceSignInEnabled
    }
  }
}
