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
    public var trustedDevicePromptAfterSignInEnabled: Bool
    public var trustedDevicePromptAfterSignUpEnabled: Bool

    public static let `default` = NativeSettings(
      apiEnabled: false,
      trustedDeviceSignInEnabled: false,
      trustedDevicePromptAfterSignInEnabled: false,
      trustedDevicePromptAfterSignUpEnabled: false
    )

    public init(
      apiEnabled: Bool,
      trustedDeviceSignInEnabled: Bool,
      trustedDevicePromptAfterSignInEnabled: Bool = false,
      trustedDevicePromptAfterSignUpEnabled: Bool = false
    ) {
      self.apiEnabled = apiEnabled
      self.trustedDeviceSignInEnabled = trustedDeviceSignInEnabled
      self.trustedDevicePromptAfterSignInEnabled = trustedDevicePromptAfterSignInEnabled
      self.trustedDevicePromptAfterSignUpEnabled = trustedDevicePromptAfterSignUpEnabled
    }

    enum CodingKeys: String, CodingKey {
      case apiEnabled
      case trustedDeviceSignInEnabled
      case trustedDevicePromptAfterSignInEnabled = "trustedDeviceEnrollmentPromptAfterSignInEnabled"
      case trustedDevicePromptAfterSignUpEnabled = "trustedDeviceEnrollmentPromptAfterSignUpEnabled"
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      apiEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiEnabled) ?? false
      trustedDeviceSignInEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .trustedDeviceSignInEnabled) ?? false
      trustedDevicePromptAfterSignInEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .trustedDevicePromptAfterSignInEnabled) ?? false
      trustedDevicePromptAfterSignUpEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .trustedDevicePromptAfterSignUpEnabled) ?? false
    }
  }
}
