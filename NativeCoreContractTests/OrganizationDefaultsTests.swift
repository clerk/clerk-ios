@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["no-form", "no-severity", "no-slug", "partial-branding"])
  func organizationDefaultsNormalizePartialResponses(scenario: String) async throws {
    let host = try OrganizationDefaultsCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let defaults = try await user.getOrganizationCreationDefaults()
    #expect(host.reads == 1)
    #expect(defaults.form.name == (scenario == "no-form" ? "" : (scenario == "partial-branding" ? "Acme" : "My Organization")))
    #expect(defaults.form.slug == (scenario == "no-severity" ? "my-organization" : ""))
    #expect(defaults.form.logo == (scenario == "partial-branding" ? "https://img.clerk.com/acme.png" : nil))
    #expect(defaults.form.blurHash == nil)
    if scenario == "no-severity" || scenario == "partial-branding" {
      #expect(defaults.advisory?.code == "organization_already_exists")
      #expect(defaults.advisory?.severity == "warning")
      #expect(defaults.advisory?.meta["organization_domain"] == (scenario == "partial-branding" ? "acme.test" : "clerk.dev"))
      #expect(defaults.advisory?.meta["organization_name"] == (scenario == "partial-branding" ? "Acme" : "Clerk"))
    } else { #expect(defaults.advisory == nil) }
  }
}

@MainActor private final class OrganizationDefaultsCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let payload: String
  var reads = 0
  var supported: [String] {
    base.supported
  }

  init(scenario: String) throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
    switch scenario {
    case "partial-branding": payload = #"{"advisory":{"code":"organization_already_exists","meta":{"organization_domain":"acme.test","organization_name":"Acme"}},"form":{"name":"Acme","logo":"https://img.clerk.com/acme.png"}}"#
    case "no-form": payload = #"{"advisory":null,"form":null}"#
    case "no-severity": payload = #"{"advisory":{"code":"organization_already_exists","meta":{"organization_domain":"clerk.dev","organization_name":"Clerk"}},"form":{"name":"My Organization","slug":"my-organization","logo":null,"blur_hash":null}}"#
    default: payload = #"{"advisory":null,"form":{"name":"My Organization","logo":null,"blur_hash":null}}"#
    }
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if try capability == "http" && arguments.object()["url"]?.url().path.hasSuffix("/organization_creation_defaults") == true {
      reads += 1
      #expect(try arguments.object()["method"] == .string("GET"))
      return .object(["status": .number(200), "headers": .object([:]), "body": .string("{\"response\":" + payload + "}")])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
