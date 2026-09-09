@testable import ClerkKit
import Foundation
import Testing

struct CorePrivacyManifestTests {
  @Test func coreBundlesItsCurrentRequiredReasonAPIDeclarations() throws {
    let url = try #require(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let manifest = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
    let accessedAPIs = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    // Secure credentials use Keychain; UserDefaults use belongs to ClerkKitUI.
    #expect(accessedAPIs.isEmpty)
  }
}
