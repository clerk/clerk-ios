import ClerkJSCore
import Foundation
import Testing

@MainActor
struct GetHelpEnvironmentTests {
  @Test
  func publishedSnapshotEnvironmentExposesSupportEmail() throws {
    let url = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var displayConfig = try #require(object["display_config"] as? [String: Any])
    let supportEmail = "help@clerk.test"
    displayConfig["support_email"] = supportEmail
    object["display_config"] = displayConfig
    let environment = try JSONDecoder().decode(
      Environment.self,
      from: JSONSerialization.data(withJSONObject: object)
    )

    let clerk = ClerkJSHost(publishableKey: "pk_test_preview")
    clerk.publishEnvironment(environment)
    #expect(clerk.environment?.displayConfig.supportEmail == supportEmail)
  }
}
