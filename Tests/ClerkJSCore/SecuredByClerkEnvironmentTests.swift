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
        Environment.self,
        from: JSONSerialization.data(withJSONObject: object)
      )

      let clerk = ClerkJSHost(publishableKey: "pk_test_preview")
      clerk.publishEnvironment(environment)
      #expect(clerk.environment?.displayConfig.branded == branded)
    }
  }

  @Test
  func publishedSnapshotShowsFooterForBrandedOnly() throws {
    let clerk = try publishedClerk(
      branded: true,
      showDevmodeWarning: false,
      instanceEnvironmentType: "development"
    )
    #expect(clerk.shouldShowDevelopmentModeWarning == false)
    #expect(clerk.shouldShowSecuredByClerkFooter == true)
  }

  @Test
  func publishedSnapshotShowsDevWarningInDevelopment() throws {
    let clerk = try publishedClerk(
      branded: false,
      showDevmodeWarning: true,
      instanceEnvironmentType: "development"
    )
    #expect(clerk.shouldShowDevelopmentModeWarning == true)
    #expect(clerk.shouldShowSecuredByClerkFooter == true)
  }

  @Test
  func publishedSnapshotHidesDevWarningInProduction() throws {
    let clerk = try publishedClerk(
      branded: false,
      showDevmodeWarning: true,
      instanceEnvironmentType: "production"
    )
    #expect(clerk.shouldShowDevelopmentModeWarning == false)
    #expect(clerk.shouldShowSecuredByClerkFooter == false)
  }

  @Test
  func missingEnvironmentHidesFooterGates() {
    let clerk = ClerkJSHost(publishableKey: "pk_test_preview")
    #expect(clerk.shouldShowDevelopmentModeWarning == false)
    #expect(clerk.shouldShowSecuredByClerkFooter == false)
  }

  private func publishedClerk(
    branded: Bool,
    showDevmodeWarning: Bool,
    instanceEnvironmentType: String
  ) throws -> ClerkJSHost {
    let url = try #require(Bundle.module.url(forResource: "environment-snapshot", withExtension: "json"))
    var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var displayConfig = try #require(object["display_config"] as? [String: Any])
    displayConfig["branded"] = branded
    displayConfig["show_devmode_warning"] = showDevmodeWarning
    displayConfig["instance_environment_type"] = instanceEnvironmentType
    object["display_config"] = displayConfig
    let environment = try JSONDecoder().decode(
      Environment.self,
      from: JSONSerialization.data(withJSONObject: object)
    )
    let clerk = ClerkJSHost(publishableKey: "pk_test_preview")
    clerk.publishEnvironment(environment)
    return clerk
  }
}
