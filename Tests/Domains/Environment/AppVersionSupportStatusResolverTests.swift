@testable import ClerkKit
import Foundation
import Testing

struct AppVersionSupportStatusResolverTests {
  @Test
  func outdatedVersionIsUnsupported() {
    let status = AppVersionSupportStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.3.0"),
      bundleID: "Com.Example.App",
      currentVersion: "2.2.9"
    )

    #expect(!status.isSupported)
    #expect(status.minimumVersion == "2.3.0")
    #expect(status.updateURL?.absoluteString == "https://apps.apple.com/app/id123")
  }

  @Test
  func equalVersionIsSupported() {
    let status = AppVersionSupportStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.3.0"),
      bundleID: "com.example.app",
      currentVersion: "2.3"
    )
    #expect(status.isSupported)
  }

  @Test
  func missingPolicyAndInvalidVersionFailOpen() {
    let missing = AppVersionSupportStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.3.0"),
      bundleID: "com.other.app",
      currentVersion: "1.0.0"
    )
    let invalid = AppVersionSupportStatusResolver.resolve(
      environment: environmentWithPolicy(minimumVersion: "2.3.0"),
      bundleID: "com.example.app",
      currentVersion: "2.0-beta"
    )

    #expect(missing.isSupported)
    #expect(invalid.isSupported)
  }

  @Test
  func strictestValidMatchingPolicyWins() {
    let status = AppVersionSupportStatusResolver.resolve(
      environment: environmentWithPolicies([
        .init(
          bundleId: "com.example.app",
          minimumVersion: "2.0.0",
          updateUrl: "https://apps.apple.com/app/id2"
        ),
        .init(
          bundleId: "COM.EXAMPLE.APP",
          minimumVersion: "3.0.0",
          updateUrl: "https://apps.apple.com/app/id3"
        ),
        .init(
          bundleId: "com.example.app",
          minimumVersion: "4.0.0",
          updateUrl: nil
        ),
      ]),
      bundleID: "com.example.app",
      currentVersion: "2.5.0"
    )

    #expect(!status.isSupported)
    #expect(status.minimumVersion == "3.0.0")
    #expect(status.updateURL?.absoluteString == "https://apps.apple.com/app/id3")
  }

  @Test(arguments: [nil, "", "app-store", "javascript:alert(1)"] as [String?])
  func policyWithoutValidUpdateURLFailsOpen(updateURL: String?) {
    let status = AppVersionSupportStatusResolver.resolve(
      environment: environmentWithPolicies([
        .init(
          bundleId: "com.example.app",
          minimumVersion: "2.0.0",
          updateUrl: updateURL
        ),
      ]),
      bundleID: "com.example.app",
      currentVersion: "1.0.0"
    )

    #expect(status.isSupported)
  }

  @Test
  func unsupportedMetaMapsOnlyMatchingIOSRequest() {
    let matching = AppVersionSupportStatusResolver.resolveFromUnsupportedAppVersionMeta(
      [
        "platform": "ios",
        "app_identifier": "Com.Example.App",
        "current_version": "1.0.0",
        "minimum_version": "3.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      requestBundleID: " com.example.app ",
      requestVersion: "1.0.0"
    )
    let android = AppVersionSupportStatusResolver.resolveFromUnsupportedAppVersionMeta(
      ["platform": "android", "app_identifier": "com.example.app"],
      requestBundleID: "com.example.app",
      requestVersion: "1.0.0"
    )

    #expect(matching?.isSupported == false)
    #expect(matching?.minimumVersion == "3.0.0")
    #expect(android == nil)
  }

  @Test(arguments: [nil, "", "app-store"] as [String?])
  func unsupportedMetaWithoutValidUpdateURLIsIgnored(updateURL: String?) {
    let updateURLJSON = updateURL.map(JSON.string) ?? .null
    let status = AppVersionSupportStatusResolver.resolveFromUnsupportedAppVersionMeta(
      [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0.0",
        "minimum_version": "3.0.0",
        "update_url": updateURLJSON,
      ],
      requestBundleID: "com.example.app",
      requestVersion: "1.0.0"
    )

    #expect(status == nil)
  }

  @Test(arguments: [
    UnsupportedMetaCase(
      name: "missing platform",
      meta: [
        "app_identifier": "com.example.app",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "missing app identifier",
      meta: [
        "platform": "ios",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "blank app identifier",
      meta: [
        "platform": "ios",
        "app_identifier": "  ",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "mismatched app identifier",
      meta: [
        "platform": "ios",
        "app_identifier": "com.other.app",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "missing request bundle identifier",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      requestBundleID: nil
    ),
    UnsupportedMetaCase(
      name: "missing current version",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "missing request version",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      requestVersion: nil
    ),
    UnsupportedMetaCase(
      name: "mismatched current version",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "invalid current version",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0-beta",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      requestVersion: "1.0-beta"
    ),
    UnsupportedMetaCase(
      name: "invalid minimum version",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "1.0.0",
        "minimum_version": "2.0.0-beta",
        "update_url": "https://apps.apple.com/app/id123",
      ]
    ),
    UnsupportedMetaCase(
      name: "current version is not below minimum",
      meta: [
        "platform": "ios",
        "app_identifier": "com.example.app",
        "current_version": "2.0.0",
        "minimum_version": "2.0.0",
        "update_url": "https://apps.apple.com/app/id123",
      ],
      requestVersion: "2.0.0"
    ),
  ])
  func inconsistentUnsupportedMetaIsIgnored(testCase: UnsupportedMetaCase) {
    let status = AppVersionSupportStatusResolver.resolveFromUnsupportedAppVersionMeta(
      testCase.meta,
      requestBundleID: testCase.requestBundleID,
      requestVersion: testCase.requestVersion
    )

    #expect(status == nil)
  }

  private func environmentWithPolicy(minimumVersion: String) -> Clerk.Environment {
    environmentWithPolicies([
      .init(
        bundleId: "com.example.app",
        minimumVersion: minimumVersion,
        updateUrl: "https://apps.apple.com/app/id123"
      ),
    ])
  }

  private func environmentWithPolicies(
    _ policies: [Clerk.Environment.MinimumSupportedVersion.IOSPolicy]
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.nativeAppSettings = .init(
      minimumSupportedVersion: .init(
        ios: policies
      )
    )
    return environment
  }
}

struct UnsupportedMetaCase: CustomTestStringConvertible {
  let name: String
  let meta: JSON
  var requestBundleID: String? = "com.example.app"
  var requestVersion: String? = "1.0.0"

  var testDescription: String {
    name
  }
}
