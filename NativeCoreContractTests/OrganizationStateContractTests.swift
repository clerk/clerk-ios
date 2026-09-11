@testable import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test(arguments: ["permissions-present", "permissions-null", "permissions-omitted", "active", "no-active", "missing-active", "manual_invitation", "automatic_invitation", "automatic_suggestion", "enterprise_sso", "future_mode"])
  func organizationStatePreservesCanonicalValues(scenario: String) async throws {
    let host = try OrganizationStateCapabilities(scenario: scenario)
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let session = try #require(clerk.session)
    let memberships = user.organizationMemberships
    #expect(memberships.map { $0.organization.id } == ["org_other", "org_active"])
    #expect(session.lastActiveOrganizationId == host.activeID)
    if let mode = host.domainModes[scenario] {
      let page = try await #require(clerk.organization).getDomains()
      #expect(page.totalCount == 1 && page.data.count == 1)
      let domain = try #require(page.data.first)
      #expect(domain.enrollmentMode == mode && domain.enrollmentMode.rawValue == scenario)
      #expect(domain.verification?.status == host.domainStatus)
      #expect(domain.affiliationVerification?.status == host.domainStatus)
      #expect(domain.organizationId == "org_active" && host.reads == 1)
    } else {
      #expect(host.reads == 0)
      if scenario.hasPrefix("permissions-") {
        let expected = scenario == "permissions-present" ? host.permissionKeys : []
        for membership in memberships {
          #expect(membership.permissions == expected)
          #expect(membership.role == "org:admin" && membership.roleName == "Admin")
        }
      }
      if host.activeID == "org_active" { #expect(clerk.organization === memberships[1].organization) }
      else { #expect(clerk.organization == nil) }
    }
    #expect(clerk.user === user && clerk.session === session)
  }
}

@MainActor private final class OrganizationStateCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  let permissionKeys = ["custom:permission", "org:sys_profile:manage", "org:sys_profile:delete", "org:sys_memberships:read", "org:sys_memberships:manage", "org:sys_domains:read", "org:sys_domains:manage", "org:sys_billing:read", "org:sys_billing:manage", "org:sys_api_keys:read", "org:sys_api_keys:manage"]
  let domainModes: [String: OrganizationEnrollmentMode] = ["manual_invitation": .manualInvitation, "automatic_invitation": .automaticInvitation, "automatic_suggestion": .automaticSuggestion, "enterprise_sso": .enterpriseSso, "future_mode": .unrecognized("future_mode")]
  let activeID: String?
  let domainStatus: OrganizationDomainVerificationStatus?
  let scenario: String
  var reads = 0

  init(scenario: String) throws {
    self.scenario = scenario
    activeID = scenario == "no-active" ? nil : (scenario == "missing-active" ? "org_missing" : "org_active")
    domainStatus = ["manual_invitation": .verified, "automatic_invitation": .unverified, "enterprise_sso": .expired, "future_mode": .unrecognized("future_status")][scenario]
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    let memberships: [JSONValue] = ["other", "active"].map { name in
      var value: [String: JSONValue] = ["object": .string("organization_membership"), "id": .string("orgmem_" + name), "role": .string("org:admin"), "role_name": .string("Admin"), "public_metadata": .object([:]), "created_at": .number(1_713_200_000_000), "updated_at": .number(1_713_200_000_000), "organization": .object(["object": .string("organization"), "id": .string("org_" + name), "name": .string(name), "slug": .string(name), "image_url": .string(""), "has_image": .bool(false), "public_metadata": .object([:]), "created_at": .number(1_713_200_000_000), "updated_at": .number(1_713_200_000_000)])]
      if scenario != "permissions-omitted" { value["permissions"] = scenario == "permissions-null" ? .null : .array(permissionKeys.map(JSONValue.string)) }
      return .object(value)
    }
    var client = try #require(base.fixtures["authenticatedClient"]).object()
    var session = try #require(try client["sessions"]?.array().first).object()
    var user = try #require(session["user"]).object()
    user["organization_memberships"] = .array(memberships)
    session["user"] = .object(user)
    session["last_active_organization_id"] = activeID.map(JSONValue.string) ?? .null
    client["sessions"] = .array([.object(session)])
    base.clientResponse = .object(client)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "http", let url = try args["url"]?.url(), url.path == "/v1/organizations/org_active/domains" {
      reads += 1
      #expect(args["method"] == .string("GET"))
      #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "_clerk_session_id" }?.value == "sess_native")
      let verification: JSONValue = domainStatus.map { .object(["status": .string($0.rawValue), "strategy": .string("email_code"), "attempts": .number(0), "expires_at": .number(1_713_200_000_000)]) } ?? .null
      let domain: JSONValue = .object(["object": .string("organization_domain"), "id": .string("orgdom_state"), "organization_id": .string("org_active"), "name": .string("example.com"), "enrollment_mode": .string(scenario), "verification": verification, "affiliation_email_address": .null, "total_pending_invitations": .number(0), "total_pending_suggestions": .number(0), "created_at": .number(1_713_200_000_000), "updated_at": .number(1_713_200_000_000)])
      let response: JSONValue = .object(["response": .object(["data": .array([domain]), "total_count": .number(1)])])
      return try .object(["status": .number(200), "headers": .object([:]), "body": .string(#require(String(data: JSONEncoder().encode(response), encoding: .utf8)))])
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
