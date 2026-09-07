//
//  PrivacyManifestTests.swift
//

import Foundation
import Testing

struct PrivacyManifestTests {
  @Test(arguments: ["ClerkKit", "ClerkKitUI"])
  func bundledManifestDeclaresUserDefaults(target: String) throws {
    // SwiftPM places the SDK resource bundles alongside the test resource bundle.
    let bundleURL = Bundle.module.bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("Clerk_\(target).bundle")
    let bundle = try #require(Bundle(url: bundleURL))
    let manifestURL = try #require(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let data = try Data(contentsOf: manifestURL)
    let manifest = try #require(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )
    let accessedAPIs = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    let userDefaults = try #require(accessedAPIs.first {
      $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
    })
    let reasons = try #require(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String])

    #expect(reasons == ["CA92.1"])
  }
}
