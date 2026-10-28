@testable import ClerkKit
import Foundation
import Testing

struct AppVersionSupportStatusResolverTests {
  @Test
  func olderVersionIsUnsupported() {
    let status = resolve(currentVersion: "2.2.9")

    #expect(!status.isSupported)
    #expect(status.currentVersion == "2.2.9")
    #expect(status.minimumVersion == "2.3.0")
    #expect(status.updateURL?.absoluteString == "https://apps.apple.com/app/id123")
  }

  @Test(arguments: ["2.3", "2.3.0", "2.10", "10"])
  func minimumOrNewerVersionIsSupported(currentVersion: String) {
    #expect(resolve(currentVersion: currentVersion).isSupported)
  }

  @Test
  func malformedVersionFailsOpen() {
    #expect(resolve(currentVersion: "2.0-beta").isSupported)
  }

  @Test
  func appWithoutPolicyIsSupported() {
    let status = resolve(bundleID: "com.example.other", currentVersion: "1.0")

    #expect(status.isSupported)
    #expect(status.minimumVersion == nil)
  }

  @Test
  func bundleIDMatchesExactlyLikeFAPI() {
    #expect(resolve(bundleID: "com.example.App", currentVersion: "1.0").isSupported)
  }

  @Test
  func nonWebUpdateURLIsDropped() {
    let status = resolve(currentVersion: "1.0", updateURL: "itms-apps://apps.apple.com/app/id123")

    #expect(!status.isSupported)
    #expect(status.updateURL == nil)
  }

  @Test
  func unsupportedAppVersionErrorBlocksWithItsDetails() {
    let status = AppVersionSupportStatusResolver.resolve(
      unsupportedAppVersionMeta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0",
        "minimum_version": "2.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      currentVersion: "1.0"
    )

    #expect(status == .init(
      isSupported: false,
      currentVersion: "1.0",
      minimumVersion: "2.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123")
    ))
  }

  @Test
  func unsupportedAppVersionErrorWithoutDetailsStillBlocks() {
    let status = AppVersionSupportStatusResolver.resolve(unsupportedAppVersionMeta: nil, currentVersion: "1.0")

    #expect(status == .init(isSupported: false, currentVersion: "1.0", minimumVersion: nil, updateURL: nil))
  }

  private func resolve(
    bundleID: String = "com.example.app",
    currentVersion: String,
    updateURL: String = "https://apps.apple.com/app/id123"
  ) -> Clerk.AppVersionSupportStatus {
    AppVersionSupportStatusResolver.resolve(
      environment: .withIOSPolicy(bundleID: "com.example.app", minimumVersion: "2.3.0", updateURL: updateURL),
      bundleID: bundleID,
      currentVersion: currentVersion
    )
  }
}

extension Clerk.Environment {
  static func withIOSPolicy(bundleID: String, minimumVersion: String, updateURL: String) -> Self {
    var environment = Clerk.Environment.mock
    environment.nativeAppSettings = .init(
      minimumSupportedVersion: .init(ios: [
        .init(bundleId: bundleID, minimumVersion: minimumVersion, updateUrl: updateURL),
      ])
    )
    return environment
  }
}
