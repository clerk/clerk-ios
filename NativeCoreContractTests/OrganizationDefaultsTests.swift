@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["no-form", "no-severity", "no-slug"])
  func organizationDefaultsNormalizePartialResponses(scenario: String) async throws {
    let host = try OrganizationDefaultsCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let defaults = try await user.getOrganizationCreationDefaults()
    #expect(host.reads == 1)
    #expect(defaults.form.name == (scenario == "no-form" ? "" : "My Organization"))
    #expect(defaults.form.slug == (scenario == "no-severity" ? "my-organization" : ""))
    #expect(defaults.form.logo == nil)
    #expect(defaults.form.blurHash == nil)
    if scenario == "no-severity" {
      #expect(defaults.advisory?.code == "organization_already_exists")
      #expect(defaults.advisory?.severity == "warning")
      #expect(defaults.advisory?.meta["organization_domain"] == "clerk.dev")
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
