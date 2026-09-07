import ClerkJSCore
import Foundation
import Testing

@MainActor
struct AppLogoEnvironmentTests {
  @Test
  func publishedSnapshotEnvironmentExposesLogoImageUrl() throws {
    let url = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var displayConfig = try #require(object["display_config"] as? [String: Any])
    let logoImageUrl = "https://img.clerk.test/logo.png"
    displayConfig["logo_image_url"] = logoImageUrl
    object["display_config"] = displayConfig
    let environment = try JSONDecoder().decode(
      ClerkEnvironment.self,
      from: JSONSerialization.data(withJSONObject: object)
    )

    #expect(environment.displayConfig.logoImageUrl == logoImageUrl)
  }
}
