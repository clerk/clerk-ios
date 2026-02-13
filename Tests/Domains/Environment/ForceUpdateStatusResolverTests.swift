@testable import ClerkKit
import Foundation
import Testing

struct ForceUpdateStatusResolverTests {
  @Test
  func outdatedVersionIsUnsupported() {
    let status = ForceUpdateStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.3.0", updateURL: "https://apps.apple.com/app/id123"),
      bundleID: "com.example.app",
      currentVersion: "2.2.9"
    )

    #expect(status.isSupported == false)
    #expect(status.reason == .belowMinimum)
    #expect(status.minimumVersion == "2.3.0")
    #expect(status.updateURL?.absoluteString == "https://apps.apple.com/app/id123")
  }

  @Test
  func missingPolicyIsSupported() {
    let status = ForceUpdateStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.3.0", updateURL: nil),
      bundleID: "com.other.app",
      currentVersion: "1.0.0"
    )

    #expect(status.isSupported == true)
    #expect(status.reason == .noPolicy)
  }

  @Test
  func invalidCurrentVersionFailsOpen() {
    let status = ForceUpdateStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.0.0", updateURL: nil),
      bundleID: "com.example.app",
      currentVersion: "2.0.0-beta"
    )

    #expect(status.isSupported == true)
    #expect(status.reason == .invalidCurrentVersion)
  }

  @Test
  func unsupportedMetaMapsToUnsupportedStatus() {
    let status = ForceUpdateStatusResolver.resolveFromUnsupportedAppVersionMeta(
      [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.2.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      bundleID: "com.example.app"
    )

    #expect(status?.isSupported == false)
    #expect(status?.reason == .serverRejected)
    #expect(status?.minimumVersion == "2.0.0")
  }

  @Test
  func unsupportedMetaIgnoresDifferentPlatform() {
    let status = ForceUpdateStatusResolver.resolveFromUnsupportedAppVersionMeta(
      [
        "platform": "android",
        "app_identifier": "com.example.app",
      ],
      bundleID: "com.example.app"
    )

    #expect(status == nil)
  }

  private func environmentWithPolicy(
    minimumVersion: String,
    updateURL: String?
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.forceUpdate = .init(
      ios: [
        .init(
          bundleId: "com.example.app",
          minimumVersion: minimumVersion,
          updateUrl: updateURL
        ),
      ],
      android: []
    )
    return environment
  }
}
