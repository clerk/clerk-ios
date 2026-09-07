import Foundation

public struct NativeSettings: Codable, Equatable, Sendable {
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
    case apiEnabled = "api_enabled"
    case biometricSignInEnabled = "trusted_device_sign_in_enabled"
    case biometricCredentialPromptAfterSignInEnabled = "trusted_device_enrollment_prompt_after_sign_in_enabled"
    case biometricCredentialPromptAfterSignUpEnabled = "trusted_device_enrollment_prompt_after_sign_up_enabled"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FAPIJSONKey.self)
    apiEnabled = try container.decodeIfPresentFlexible(Bool.self, snake: "api_enabled", camel: "apiEnabled") ?? false
    biometricSignInEnabled =
      try container.decodeIfPresentFlexible(Bool.self, snake: "trusted_device_sign_in_enabled", camel: "trustedDeviceSignInEnabled") ?? false
    biometricCredentialPromptAfterSignInEnabled =
      try container.decodeIfPresentFlexible(Bool.self, snake: "trusted_device_enrollment_prompt_after_sign_in_enabled", camel: "trustedDeviceEnrollmentPromptAfterSignInEnabled") ?? false
    biometricCredentialPromptAfterSignUpEnabled =
      try container.decodeIfPresentFlexible(Bool.self, snake: "trusted_device_enrollment_prompt_after_sign_up_enabled", camel: "trustedDeviceEnrollmentPromptAfterSignUpEnabled") ?? false
  }
}

extension FAPIJSON {
  public static func decodeNativeSettings(fromEnvironmentJSON data: Data) throws -> NativeSettings {
    try JSONDecoder().decode(EnvironmentNativeSettings.self, from: data).nativeSettings
  }
}

private struct EnvironmentNativeSettings: Decodable {
  var nativeSettings: NativeSettings

  init(from decoder: Decoder) throws {
    let root = try decoder.container(keyedBy: RootKeys.self)
    let authConfig = try root.decodeIfPresent(AuthConfigNativeSettings.self, forKey: .authConfig)
    nativeSettings = authConfig?.nativeSettings ?? .default
  }

  enum RootKeys: String, CodingKey {
    case authConfig = "auth_config"
  }
}

private struct AuthConfigNativeSettings: Decodable {
  var nativeSettings: NativeSettings

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    nativeSettings = try container.decodeIfPresent(NativeSettings.self, forKey: .nativeSettings) ?? .default
  }

  enum CodingKeys: String, CodingKey {
    case nativeSettings = "native_settings"
  }
}
