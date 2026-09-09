import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor @Suite(.serialized) struct OrganizationMembershipTests {
  @Test(arguments: [false, true])
  func deletionReturnsReadableMembershipAfterItsOrganizationIsDeselected(fullResource: Bool) async throws {
    let host = try MembershipDeletionCapabilities(fullResource: fullResource)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let membership = try #require(user.organizationMemberships.first)
    #expect(clerk.organization?.id == "org_membership")
    let removed: OrganizationMembership = try await membership.destroy()
    #expect(removed.id == "orgmem_native")
    #expect(removed.role == "org:member")
    #expect(removed.publicMetadata["source"] == .string(fullResource ? "server" : "before"))
    #expect(removed.organization.name == "Membership Org")
    #expect(user.organizationMemberships.isEmpty)
    #expect(clerk.organization == nil)
    #expect(host.deleted)
    try await clerk.signIn.reset()
    #expect(clerk.loaded)
  }
}

@MainActor private final class MembershipDeletionCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let fullResource: Bool
  private var client: [String: JSONValue]
  private let membership: JSONValue
  private(set) var deleted = false

  init(fullResource: Bool) throws {
    self.fullResource = fullResource
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    membership = try JSONDecoder().decode(JSONValue.self, from: Data("""
    {"object":"organization_membership","id":"orgmem_native","role":"org:member","role_name":"Member","permissions":[],"public_metadata":{"source":"before"},"created_at":1700000000000,"updated_at":1700000000000,
    "public_user_data":{"user_id":"user_native","first_name":"Test","last_name":"User","image_url":"","has_image":false,"identifier":"test@example.com"},
    "organization":{"object":"organization","id":"org_membership","name":"Membership Org","slug":"membership-org","image_url":"","has_image":false,"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000}}
    """.utf8))
    client = try #require(base.fixtures["authenticatedClient"]).object()
    var session = try #require(client["sessions"]).array()[0].object()
    var user = try #require(session["user"]).object()
    user["organization_memberships"] = .array([membership])
    session["user"] = .object(user)
    session["last_active_organization_id"] = .string("org_membership")
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let url = try #require(args["url"]).url()
    guard url.path.contains("/memberships/") else { return try await base.perform(capability, arguments: arguments) }
    #expect(url.path == "/v1/organizations/org_membership/memberships/user_native")
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let method = try query.first(where: { $0.name == "_method" })?.value ?? (#require(args["method"]).string())
    #expect(method == "DELETE")
    #expect(query.contains { $0.name == "_clerk_session_id" && $0.value == "sess_native" })
    var session = try #require(client["sessions"]).array()[0].object()
    var user = try #require(session["user"]).object()
    user["organization_memberships"] = .array([])
    session["user"] = .object(user)
    session["last_active_organization_id"] = .null
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
    var returned = fullResource ? try membership.object() : ["object": .string("organization_membership"), "id": .string("orgmem_native"), "deleted": .bool(true)]
    if fullResource { returned["public_metadata"] = .object(["source": .string("server")]) }
    deleted = true
    let body = try JSONEncoder().encode(JSONValue.object(["response": .object(returned), "client": .object(client)]))
    return .object(["status": .number(200), "headers": .object(["authorization": .string("fixture-client-credential")]), "body": .string(String(decoding: body, as: UTF8.self))])
  }
}
