@testable import ClerkKit
import Foundation
import Testing

struct ForceUpdateDecodingTests {
  @Test
  func forceUpdateIsNilWhenForceUpdateObjectIsMissing() throws {
    let environment = try decodeEnvironment(forceUpdate: nil)
    #expect(environment.forceUpdate == nil)
  }

  @Test
  func missingAndroidPoliciesDecodeAsEmptyList() throws {
    let environment = try decodeEnvironment(forceUpdate: [
      "ios": [
        [
          "bundle_id": "com.example.app",
          "minimum_version": "2.0.0",
          "update_url": "https://apps.apple.com/app/id123",
        ],
      ],
    ])

    #expect(environment.forceUpdate?.ios.count == 1)
    #expect(environment.forceUpdate?.ios.first?.bundleId == "com.example.app")
    #expect(environment.forceUpdate?.android.isEmpty == true)
  }

  @Test
  func missingIOSPoliciesDecodeAsEmptyList() throws {
    let environment = try decodeEnvironment(forceUpdate: [
      "android": [
        [
          "package_name": "com.example.app",
          "minimum_version": "2.0.0",
          "update_url": "https://play.google.com/store/apps/details?id=com.example.app",
        ],
      ],
    ])

    #expect(environment.forceUpdate?.ios.isEmpty == true)
    #expect(environment.forceUpdate?.android.count == 1)
    #expect(environment.forceUpdate?.android.first?.packageName == "com.example.app")
  }

  private func decodeEnvironment(forceUpdate: [String: Any]?) throws -> Clerk.Environment {
    let encoded = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    var payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    if let forceUpdate {
      payload["force_update"] = forceUpdate
    } else {
      payload.removeValue(forKey: "force_update")
    }

    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: data)
  }
}
