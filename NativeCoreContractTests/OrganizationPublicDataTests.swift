@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: [false, true], ["present", "null", "omitted", "mixed"])
  func organizationPublicDataDefaultsMissingBranding(suggestion: Bool, scenario: String) async throws {
    let host = try OrganizationPublicDataCapabilities(suggestion: suggestion, scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let session = clerk.session
    let data: (imageUrl: String, slug: String?, hasImage: Bool, id: String, name: String)
    let created: Date
    let updated: Date
    if suggestion {
      let page = try await user.getOrganizationSuggestions()
      #expect(page.totalCount == 1)
      let resource = try #require(page.data.first)
      #expect(page.data.count == 1 && resource.id == "resource_projection" && resource.status.rawValue == "pending")
      let value = resource.publicOrganizationData
      data = (value.imageUrl, value.slug, value.hasImage, value.id, value.name)
      created = resource.createdAt; updated = resource.updatedAt
    } else {
      let page = try await user.getOrganizationInvitations()
      #expect(page.totalCount == 1)
      let resource = try #require(page.data.first)
      #expect(page.data.count == 1 && resource.id == "resource_projection" && resource.status.rawValue == "pending")
      #expect(resource.publicMetadata == host.metadata)
      let value = resource.publicOrganizationData
      data = (value.imageUrl, value.slug, value.hasImage, value.id, value.name)
      created = resource.createdAt; updated = resource.updatedAt
    }
    #expect(data.imageUrl == (scenario == "present" ? "https://fixture.test/logo.png" : ""))
    #expect(data.slug == (scenario == "present" ? "acme" : nil))
    #expect(data.hasImage == (scenario == "present"))
    #expect(data.id == "org_123" && data.name == "Acme")
    #expect(created.timeIntervalSince1970 == 1_713_200_000)
    #expect(updated.timeIntervalSince1970 == 1_713_208_673)
    #expect(host.reads == 1 && clerk.user === user && clerk.session === session)
  }
}

@MainActor private final class OrganizationPublicDataCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let kind: String
  let payload: JSONValue
  let metadata: [String: JSONValue] = ["source": .string("test"), "nested": .object(["retained": .null]), "count": .number(3)]
  var reads = 0

  init(suggestion: Bool, scenario: String) throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
    kind = suggestion ? "suggestion" : "invitation"
    var organization: [String: JSONValue] = ["id": .string("org_123"), "name": .string("Acme"), "has_image": .bool(scenario == "present")]
    if scenario == "present" { organization["image_url"] = .string("https://fixture.test/logo.png"); organization["slug"] = .string("acme") }
    if scenario == "null" || scenario == "mixed" { organization["image_url"] = .null }
    if scenario == "null" { organization["slug"] = .null }
    payload = .object(["object": .string("organization_" + kind), "id": .string("resource_projection"), "email_address": .string("sam@example.com"), "role": .string("org:member"), "status": .string("pending"), "public_metadata": .object(metadata), "created_at": .number(1_713_200_000_000), "updated_at": .string("2024-04-15T19:17:53Z"), "public_organization_data": .object(organization)])
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "http", let url = try args["url"]?.url(), url.path == "/v1/me/organization_\(kind)s" {
      reads += 1
      #expect(args["method"] == .string("GET"))
      #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "_clerk_session_id" }?.value == "sess_native")
      let response: JSONValue = .object(["response": .object(["data": .array([payload]), "total_count": .number(1)])])
      let body = try #require(String(data: JSONEncoder().encode(response), encoding: .utf8))
      return .object(["status": .number(200), "headers": .object([:]), "body": .string(body)])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
