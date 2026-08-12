@testable import ClerkKit
import Foundation
import Testing

struct AuthConfigDecodingTests {
  private let decoder = JSONDecoder.clerkDecoder
  private let encoder = JSONEncoder.clerkEncoder

  @Test
  func nativeSettingsDecodeTrustedDeviceSignInEnabled() throws {
    let data = Data(
      """
      {
        "single_session_mode": false,
        "native_settings": {
          "api_enabled": true,
          "trusted_device_sign_in_enabled": true,
          "trusted_device_enrollment_prompt_after_sign_in_enabled": true,
          "trusted_device_enrollment_prompt_after_sign_up_enabled": true
        }
      }
      """.utf8
    )

    let authConfig = try decoder.decode(Clerk.Environment.AuthConfig.self, from: data)

    #expect(authConfig.singleSessionMode == false)
    #expect(authConfig.nativeSettings.apiEnabled == true)
    #expect(authConfig.nativeSettings.trustedDeviceSignInEnabled == true)
    #expect(authConfig.nativeSettings.trustedDevicePromptAfterSignInEnabled == true)
    #expect(authConfig.nativeSettings.trustedDevicePromptAfterSignUpEnabled == true)
  }

  @Test
  func nativeSettingsDefaultWhenMissing() throws {
    let data = Data(
      """
      {
        "single_session_mode": true
      }
      """.utf8
    )

    let authConfig = try decoder.decode(Clerk.Environment.AuthConfig.self, from: data)

    #expect(authConfig.singleSessionMode == true)
    #expect(authConfig.nativeSettings == .default)
  }

  @Test
  func nativeSettingsEncodeBackendKeys() throws {
    let authConfig = Clerk.Environment.AuthConfig(
      singleSessionMode: false,
      nativeSettings: .init(
        apiEnabled: true,
        trustedDeviceSignInEnabled: true,
        trustedDevicePromptAfterSignInEnabled: true,
        trustedDevicePromptAfterSignUpEnabled: true
      )
    )

    let data = try encoder.encode(authConfig)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let nativeSettings = try #require(object["native_settings"] as? [String: Any])

    #expect(object["single_session_mode"] as? Bool == false)
    #expect(nativeSettings["api_enabled"] as? Bool == true)
    #expect(nativeSettings["trusted_device_sign_in_enabled"] as? Bool == true)
    #expect(nativeSettings["trusted_device_enrollment_prompt_after_sign_in_enabled"] as? Bool == true)
    #expect(nativeSettings["trusted_device_enrollment_prompt_after_sign_up_enabled"] as? Bool == true)
  }
}
