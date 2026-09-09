@testable import ClerkKitUI
import Foundation
import Testing

struct UIPrivacyManifestTests {
  @Test func bundledManifestDeclaresUserDefaults() throws {
    let url = try #require(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let manifest = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
    let accessedAPIs = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    let userDefaults = try #require(accessedAPIs.first {
      $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
    })
    #expect(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
  }
}
