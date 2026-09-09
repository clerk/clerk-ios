@testable import ClerkKit
import Foundation
import Testing

struct CorePrivacyManifestTests {
  @Test func coreBundlesItsCurrentRequiredReasonAPIDeclarations() throws {
    let url = try #require(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let manifest = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
    let accessedAPIs = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    // The app-container marker distinguishes an upgrade from surviving keys after reinstall.
    #expect(accessedAPIs.count == 1)
    #expect(accessedAPIs.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
    #expect(accessedAPIs.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
  }
}
