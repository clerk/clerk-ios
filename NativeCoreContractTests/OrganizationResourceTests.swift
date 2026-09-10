@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["receipt", "resource", "rejected", "refresh-failed", "fetched", "filters"])
  func organizationResourcesPreserveReturnedState(scenario: String) async throws {
    let host = try OrganizationResourceCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let root = try #require(clerk.organization)
    if scenario == "fetched" {
      let fetched = try await clerk.getOrganization(root.id)
      #expect(fetched !== root)
      #expect(fetched.name == "Fetched organization")
      #expect(root.name == "Original organization")
      let updated = try await fetched.update(.init(name: "Updated organization"))
      #expect(updated.name == "Updated organization")
      #expect(fetched.name == "Updated organization")
      #expect(root.name == "Original organization")
    } else if scenario == "filters" {
      let page = try await root.getInvitations(.init(initialPage: 3, pageSize: 10, status: []))
      #expect(page.data.isEmpty && page.totalCount == 0)
      let request = try #require(host.requests.last).object()
      let url = try #require(request["url"]).url()
      let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      #expect(!query.contains { $0.name == "status" })
      #expect(query.contains { $0.name == "offset" && $0.value == "20" })
      #expect(query.contains { $0.name == "limit" && $0.value == "10" })
    } else if scenario == "rejected" || scenario == "refresh-failed" {
      do {
        _ = try await root.setLogo(.init(file: nil))
        Issue.record("Expected organization request failure")
      } catch let error as CoreError {
        #expect(error.errors.first?.code == "not_allowed_access")
      }
      #expect(root.name == "Original organization" && root.hasImage)
    } else {
      let result = try await root.setLogo(.init(file: nil))
      #expect(result.id == root.id)
      #expect(result.name == "Original organization")
      #expect(!result.hasImage && result.imageUrl == "")
      #expect(host.requests.count == (scenario == "receipt" ? 2 : 1))
      if scenario == "receipt" { #expect(!root.hasImage) }
    }
    for request in host.requests {
      let args = try request.object()
      let url = try #require(args["url"]).url()
      let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      #expect(query.contains { $0.name == "_clerk_session_id" && $0.value == "sess_native" })
      if url.path.hasSuffix("/logo") {
        #expect(args["method"] == .string("POST"))
        #expect(query.contains { $0.name == "_method" && $0.value == "DELETE" })
      }
    }
  }
}

@MainActor private final class OrganizationResourceCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  let scenario: String
  let organization: [String: JSONValue]
  var requests: [JSONValue] = []
  var supported: [String] {
    base.supported
  }

  init(scenario: String) throws {
    self.scenario = scenario
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    organization = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"object":"organization","id":"org_resource","name":"Original organization","slug":"original","has_image":true,"image_url":"https://images.example/logo.png","public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000}"#.utf8)).object()
    let membership: JSONValue = .object([
      "object": .string("organization_membership"), "id": .string("orgmem_resource"),
      "role": .string("org:member"), "role_name": .string("Member"), "permissions": .array([]),
      "public_metadata": .object([:]), "organization": .object(organization),
      "created_at": .number(1_700_000_000_000), "updated_at": .number(1_700_000_000_000),
    ])
    var client = try #require(base.fixtures["authenticatedClient"]).object()
    var session = try #require(client["sessions"]).array()[0].object()
    var user = try #require(session["user"]).object()
    user["organization_memberships"] = .array([membership])
    session["user"] = .object(user)
    session["last_active_organization_id"] = .string("org_resource")
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let url = try #require(args["url"]).url()
    guard url.path.hasPrefix("/v1/organizations/org_resource") else { return try await base.perform(capability, arguments: arguments) }
    requests.append(arguments)
    let failed = scenario == "rejected" || (scenario == "refresh-failed" && !url.path.hasSuffix("/logo"))
    let payload: JSONValue
    if failed {
      payload = .object(["errors": .array([.object(["code": .string("not_allowed_access"), "message": .string("Not allowed")])])])
    } else if url.path.hasSuffix("/logo"), scenario != "resource" {
      payload = .object(["response": .object(["object": .string("image"), "id": .string("img_resource"), "deleted": .bool(true)])])
    } else if url.path.hasSuffix("/invitations") {
      payload = .object(["response": .object(["data": .array([]), "total_count": .number(0)])])
    } else {
      var value = organization
      if scenario == "fetched" {
        value["name"] = .string(args["method"] == .string("GET") ? "Fetched organization" : "Updated organization")
      } else {
        value["has_image"] = .bool(false)
        value["image_url"] = .string("")
      }
      payload = .object(["response": .object(value)])
    }
    return try .object(["status": .number(failed ? 403 : 200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(payload), as: UTF8.self))])
  }
}
