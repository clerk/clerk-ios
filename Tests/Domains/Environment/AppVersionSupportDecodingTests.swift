@testable import ClerkKit
import Foundation
import Testing

struct AppVersionSupportDecodingTests {
  @Test
  func nativeAppSettingsDecodeWhenPresent() throws {
    let environment = try decodeEnvironment(nativeAppSettings: [
      "minimum_supported_version": [
        "ios": [],
      ],
    ])

    #expect(environment.nativeAppSettings.minimumSupportedVersion.ios.isEmpty == true)
  }

  @Test
  func missingAndroidPoliciesStillDecode() throws {
    let environment = try decodeEnvironment(nativeAppSettings: [
      "minimum_supported_version": [
        "ios": [
          [
            "bundle_id": "com.example.app",
            "minimum_version": "2.0.0",
            "update_url": "https://apps.apple.com/app/id123",
          ],
        ],
      ],
    ])

    #expect(environment.nativeAppSettings.minimumSupportedVersion.ios.count == 1)
    #expect(environment.nativeAppSettings.minimumSupportedVersion.ios.first?.bundleId == "com.example.app")
  }

  @Test
  func androidPoliciesAreIgnored() throws {
    let environment = try decodeEnvironment(nativeAppSettings: [
      "minimum_supported_version": [
        "android": [
          [
            "package_name": "com.example.app",
            "minimum_version": "2.0.0",
            "update_url": "https://play.google.com/store/apps/details?id=com.example.app",
          ],
        ],
      ],
    ])

    #expect(environment.nativeAppSettings.minimumSupportedVersion.ios.isEmpty == true)
  }

  private func decodeEnvironment(nativeAppSettings: [String: Any]) throws -> Clerk.Environment {
    let encoded = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    var payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    payload["native_app_settings"] = nativeAppSettings

    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
  }
}
