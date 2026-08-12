@testable import ClerkKit
import Foundation
import Testing

struct AppVersionSupportDecodingTests {
  @Test
  func nativeAppSettingsDefaultWhenMissing() throws {
    let environment = try decodeEnvironment(nativeAppSettings: nil)
    #expect(environment.nativeAppSettings.minimumSupportedVersion.ios.isEmpty)
  }

  @Test
  func policyDecodesWhenPresent() throws {
    let environment = try decodeEnvironment(nativeAppSettings: [
      "minimum_supported_version": [
        "ios": [[
          "bundle_id": "com.example.app",
          "minimum_version": "2.0.0",
          "update_url": "https://apps.apple.com/app/id123",
        ]],
        "android": [],
      ],
    ])

    let policy = try #require(environment.nativeAppSettings.minimumSupportedVersion.ios.first)
    #expect(policy.bundleId == "com.example.app")
    #expect(policy.minimumVersion == "2.0.0")
    #expect(policy.updateUrl == "https://apps.apple.com/app/id123")
  }

  @Test
  func missingIOSPoliciesDefaultToEmpty() throws {
    let environment = try decodeEnvironment(nativeAppSettings: [
      "minimum_supported_version": ["android": []],
    ])
    #expect(environment.nativeAppSettings.minimumSupportedVersion.ios.isEmpty)
  }

  private func decodeEnvironment(nativeAppSettings: [String: Any]?) throws -> Clerk.Environment {
    let encoded = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    var payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    if let nativeAppSettings {
      payload["native_app_settings"] = nativeAppSettings
    } else {
      payload.removeValue(forKey: "native_app_settings")
    }

    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
  }
}
