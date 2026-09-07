import ClerkJSCore
import Foundation
import Testing

@MainActor
struct SecuredByClerkEnvironmentTests {
  @Test
  func publishedSnapshotEnvironmentExposesBranded() throws {
    let url = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    let original = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])

    for branded in [true, false] {
      var object = original
      var displayConfig = try #require(object["display_config"] as? [String: Any])
      displayConfig["branded"] = branded
      object["display_config"] = displayConfig
      let environment = try JSONDecoder().decode(
        ClerkEnvironment.self,
        from: JSONSerialization.data(withJSONObject: object)
      )

      #expect(environment.displayConfig.branded == branded)
    }
  }
}
