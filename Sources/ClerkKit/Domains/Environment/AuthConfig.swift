//
//  AuthConfig.swift
//  Clerk
//

import Foundation

extension Clerk.Environment {
  public struct AuthConfig: Codable, Sendable, Equatable {
    public var singleSessionMode: Bool
    public var sessionMinter: Bool
    public var nativeSettings: NativeSettings

    public init(
      singleSessionMode: Bool,
      sessionMinter: Bool = false,
      nativeSettings: NativeSettings = .default
    ) {
      self.singleSessionMode = singleSessionMode
      self.sessionMinter = sessionMinter
      self.nativeSettings = nativeSettings
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      singleSessionMode = try container.decode(Bool.self, forKey: .singleSessionMode)
      sessionMinter = try container.decodeIfPresent(Bool.self, forKey: .sessionMinter) ?? false
      nativeSettings = try container.decodeIfPresent(NativeSettings.self, forKey: .nativeSettings) ?? .default
    }
  }
}

extension Clerk.Environment.AuthConfig {
  public struct NativeSettings: Codable, Sendable, Equatable {
    public var apiEnabled: Bool
    public var biometricSignInEnabled: Bool
    public var biometricCredentialPromptAfterSignInEnabled: Bool
    public var biometricCredentialPromptAfterSignUpEnabled: Bool

    public static let `default` = NativeSettings(
      apiEnabled: false,
      biometricSignInEnabled: false,
      biometricCredentialPromptAfterSignInEnabled: false,
      biometricCredentialPromptAfterSignUpEnabled: false
    )

    public init(
      apiEnabled: Bool,
      biometricSignInEnabled: Bool,
      biometricCredentialPromptAfterSignInEnabled: Bool = false,
      biometricCredentialPromptAfterSignUpEnabled: Bool = false
    ) {
      self.apiEnabled = apiEnabled
      self.biometricSignInEnabled = biometricSignInEnabled
      self.biometricCredentialPromptAfterSignInEnabled = biometricCredentialPromptAfterSignInEnabled
      self.biometricCredentialPromptAfterSignUpEnabled = biometricCredentialPromptAfterSignUpEnabled
    }

    enum CodingKeys: String, CodingKey {
      case apiEnabled
      case biometricSignInEnabled = "trustedDeviceSignInEnabled"
      case biometricCredentialPromptAfterSignInEnabled = "trustedDeviceEnrollmentPromptAfterSignInEnabled"
      case biometricCredentialPromptAfterSignUpEnabled = "trustedDeviceEnrollmentPromptAfterSignUpEnabled"
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      apiEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiEnabled) ?? false
      biometricSignInEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .biometricSignInEnabled) ?? false
      biometricCredentialPromptAfterSignInEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .biometricCredentialPromptAfterSignInEnabled) ?? false
      biometricCredentialPromptAfterSignUpEnabled =
        try container.decodeIfPresent(Bool.self, forKey: .biometricCredentialPromptAfterSignUpEnabled) ?? false
    }
  }
}
