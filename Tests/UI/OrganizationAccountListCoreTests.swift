#if os(iOS) || os(macOS)
@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor @Suite(.serialized) struct OrganizationAccountListCoreTests {
  @Test(arguments: Array(-1 ... 6))
  func organizationActionsRequireTheirOwnPermission(grantIndex: Int) async throws {
    let grants = ["org:sys_profile:manage", "org:sys_profile:delete", "org:sys_memberships:read", "org:sys_memberships:manage", "org:sys_domains:read", "org:sys_domains:manage", "custom:permission"]
    let host = try OrganizationListCapabilities()
    var payload = try host.membership(id: "permissions").object()
    payload["permissions"] = .array(grantIndex < 0 ? [] : [.string(grants[grantIndex])])
    host.memberships = [.object(payload)]
    let clerk = try await host.connect()
    defer { clerk.close() }
    let page = try await #require(clerk.user).getOrganizationMemberships()
    let member = try #require(page.data.first)
    let actions = [member.canManageProfile, member.canDeleteOrganization, member.canReadMemberships, member.canManageMemberships, member.canReadDomains, member.canManageDomains]
    #expect(actions == (0 ..< 6).map { $0 == grantIndex })
  }

  @Test(arguments: ["verified", "unverified", "failed", "expired", "future_status", "absent"])
  func organizationDomainPresentationRequiresVerifiedStatus(status: String) async throws {
    let host = try OrganizationListCapabilities()
    host.memberships = try [host.membership(id: "verification")]
    let verification: JSONValue = status == "absent" ? .null : .object(["status": .string(status), "strategy": .string("email_code"), "attempts": .number(0), "expires_at": .number(1_713_200_000_000)])
    host.domains = [.object(["object": .string("organization_domain"), "id": .string("orgdom_ui"), "organization_id": .string("org_verification"), "name": .string("example.com"), "enrollment_mode": .string("manual_invitation"), "verification": verification, "affiliation_email_address": .null, "total_pending_invitations": .number(0), "total_pending_suggestions": .number(0), "created_at": .number(1_713_200_000_000), "updated_at": .number(1_713_200_000_000)])]
    let clerk = try await host.connect()
    defer { clerk.close() }
    let memberships = try await #require(clerk.user).getOrganizationMemberships()
    let organization = try #require(memberships.data.first).organization
    let page = try await organization.getDomains()
    let domain = try #require(page.data.first)
    #expect(domain.isVerified == (status == "verified"))
  }

  @Test func initialLoadUsesGeneratedCollectionsAndCreationDefaults() async throws {
    let host = try OrganizationListCapabilities()
    host.memberships = try [host.membership(id: "mem_1")]
    host.invitations = try [host.invitation(id: "inv_1")]
    host.suggestions = try [host.suggestion(id: "sug_1")]
    let clerk = try await host.connect()
    defer { clerk.close() }
    let model = OrganizationAccountListDataSource(pageSize: 3)
    await model.loadInitial(user: clerk.user, includeCreationDefaults: true)
    #expect(!model.isLoading && model.error == nil)
    #expect(model.membershipsPager.items.map(\.id) == ["mem_1"])
    #expect(model.invitationsPager.items.map(\.id) == ["inv_1"])
    #expect(model.suggestionsPager.items.map(\.id) == ["sug_1"])
    #expect(model.creationDefaults?.form.name == "Suggested organization")
    #expect(model.creationDefaults?.form.slug == "suggested")
    #expect(model.creationDefaults?.form.logo == nil && model.creationDefaults?.form.blurHash == nil)
    #expect(model.creationDefaults?.advisory == nil && model.hasExistingResources)
    for suffix in ["organization_memberships", "organization_invitations", "organization_suggestions"] {
      let request = try #require(host.requests.first { $0.path.hasSuffix(suffix) })
      #expect(request.query["offset"] == "0" && request.query["limit"] == "3")
    }
    #expect(host.requests.first { $0.path.hasSuffix("organization_invitations") }?.query["status"] == "pending")
    #expect(host.requests.first { $0.path.hasSuffix("organization_suggestions") }?.query["status"] == "pending,accepted")
  }

  @Test func emptyCollectionsFinishLoadingWithoutRequestingDefaults() async throws {
    let host = try OrganizationListCapabilities()
    let clerk = try await host.connect()
    defer { clerk.close() }
    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: clerk.user, includeCreationDefaults: false)
    #expect(!model.isLoading && !model.hasExistingResources && !model.hasNextPage)
    #expect(model.error == nil && model.creationDefaults == nil)
    #expect(!host.requests.contains { $0.path.hasSuffix("organization_creation_defaults") })
  }

  @Test func failedInitialLoadCanBeRetriedAndClearsLoadingState() async throws {
    let host = try OrganizationListCapabilities()
    host.failedCollection = "organization_memberships"
    let clerk = try await host.connect()
    defer { clerk.close() }
    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: clerk.user, includeCreationDefaults: false)
    #expect(!model.isLoading && model.error != nil)
    host.failedCollection = nil
    await model.loadInitial(user: clerk.user, includeCreationDefaults: false)
    #expect(!model.isLoading && model.error == nil)
  }

  @Test func aPartialMembershipPageDoesNotSkipTheNextMember() async throws {
    let host = try OrganizationListCapabilities()
    host.memberships = try (1 ... 2).map { try host.membership(id: "mem_\($0)") }
    host.firstMembershipPageSize = 1
    let clerk = try await host.connect()
    defer { clerk.close() }
    let model = OrganizationAccountListDataSource(pageSize: 4)
    await model.loadInitial(user: clerk.user, includeCreationDefaults: false)
    #expect(model.membershipsPager.items.map(\.id) == ["mem_1"])
    #expect(model.membershipsPager.hasNextPage)
    await model.loadMoreMemberships(user: clerk.user)
    #expect(model.error == nil)
    #expect(model.membershipsPager.items.map(\.id) == ["mem_1", "mem_2"])
    #expect(!model.membershipsPager.hasNextPage && !model.isLoadingMore)
  }

  @Test func loadedMembershipPagesPreserveTheRevalidationWindow() async throws {
    let host = try OrganizationListCapabilities()
    host.memberships = try (1 ... 21).map { try host.membership(id: "mem_\($0)") }
    let clerk = try await host.connect()
    defer { clerk.close() }
    let user = try #require(clerk.user)
    let first = try await user.getOrganizationMemberships(.init(initialPage: 1, pageSize: 10))
    let second = try await user.getOrganizationMemberships(.init(initialPage: 2, pageSize: 10))
    var pager = OrganizationAccountListPager<OrganizationMembership>()
    #expect(pager.loadedPageOffsets(pageSize: 10) == [0])
    pager.replace(data: first.data, totalCount: first.totalCount)
    #expect(pager.loadedPageOffsets(pageSize: 10) == [0])
    pager.append(data: second.data, totalCount: second.totalCount)
    #expect(pager.loadedPageOffsets(pageSize: 10) == [0, 10])
    pager.replace(pages: [(data: first.data, totalCount: first.totalCount), (data: second.data, totalCount: second.totalCount)])
    #expect(pager.items.map(\.id) == (1 ... 20).map { "mem_\($0)" })
    #expect(pager.offset == 20 && pager.totalCount == 21 && pager.hasNextPage)
    let third = try await user.getOrganizationMemberships(.init(initialPage: Double(pager.nextPage(pageSize: 10)), pageSize: 10))
    pager.append(data: third.data, totalCount: third.totalCount)
    #expect(pager.items.map(\.id) == (1 ... 21).map { "mem_\($0)" })
    #expect(pager.loadedPageOffsets(pageSize: 10) == [0, 10, 20] && !pager.hasNextPage)
  }

  @Test(arguments: [1, 3, 11]) func acceptingAnInvitationKeepsItsRowAndDoesNotSkipTheNextPendingInvitation(count: Int) async throws {
    let host = try OrganizationListCapabilities()
    host.invitations = try (1 ... count).map { try host.invitation(id: "inv_\($0)") }
    let clerk = try await host.connect()
    defer { clerk.close() }
    let pageSize = count == 1 ? 2 : count - 1
    let model = OrganizationAccountListDataSource(pageSize: pageSize)
    await model.loadInitial(user: clerk.user, includeCreationDefaults: false)
    #expect(model.error == nil)
    #expect(model.invitationsPager.items.map(\.id) == (1 ... min(pageSize, count)).map { "inv_\($0)" })
    let invitation = try #require(model.invitationsPager.items.first)
    await model.acceptInvitation(invitation)
    #expect(model.error == nil)
    #expect(model.invitationsPager.items.first?.status == .accepted)
    #expect(model.invitationsPager.offset == min(pageSize, count) - 1 && model.invitationsPager.totalCount == count - 1)
    #expect(model.invitationsPager.hasNextPage == (count > pageSize))
    await model.loadMoreInvitations(user: clerk.user)
    #expect(model.error == nil)
    #expect(model.invitationsPager.items.map(\.id) == (1 ... count).map { "inv_\($0)" })
    #expect(model.invitationsPager.items.map(\.status) == [.accepted] + Array(repeating: .pending, count: count - 1))
    #expect(model.invitationsPager.offset == count - 1 && !model.invitationsPager.hasNextPage)
    #expect(invitation.publicOrganizationData.id == "org_inv_1")
    #expect(!host.requests.contains { $0.path.contains("/organizations/") })
  }

  @Test func acceptedSuggestionRemainsVisibleWithItsUpdatedStatus() async throws {
    let host = try OrganizationListCapabilities()
    host.suggestions = try [host.suggestion(id: "sug_1")]
    let clerk = try await host.connect()
    defer { clerk.close() }
    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: clerk.user, includeCreationDefaults: false)
    let suggestion = try #require(model.suggestionsPager.items.first)
    await model.acceptSuggestion(suggestion)
    #expect(model.error == nil)
    #expect(model.suggestionsPager.items.map(\.id) == ["sug_1"])
    #expect(model.suggestionsPager.items.first?.status == .accepted)
  }
}

@MainActor private final class OrganizationListCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var invitations: [JSONValue] = []
  var memberships: [JSONValue] = []
  var suggestions: [JSONValue] = []
  var domains: [JSONValue] = []
  var requests: [(path: String, query: [String: String])] = []
  var failedCollection: String?
  var firstMembershipPageSize: Int?

  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = try #require(base.fixtures["authenticatedClient"])
  }

  func connect() async throws -> Clerk {
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    return try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: URL(string: "clerk-test://sso-callback")!), capabilities: self)
  }

  func invitation(id: String, status: String = "pending") throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data("""
    {"object":"organization_invitation","id":"\(id)","email_address":"person@example.com","public_organization_data":{"id":"org_\(id)","name":"Organization \(id)","slug":null,"image_url":"","has_image":false},"public_metadata":{},"role":"org:member","status":"\(status)","created_at":1700000000000,"updated_at":1700000000000}
    """.utf8))
  }

  func membership(id: String) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data("""
    {"object":"organization_membership","id":"\(id)","organization":{"object":"organization","id":"org_\(id)","name":"Organization \(id)","slug":null,"image_url":"","has_image":false,"public_metadata":{},"created_at":1700000000000,"updated_at":1700000000000},"public_metadata":{},"role":"org:member","role_name":"Member","permissions":[],"created_at":1700000000000,"updated_at":1700000000000}
    """.utf8))
  }

  func suggestion(id: String, status: String = "pending") throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data("""
    {"object":"organization_suggestion","id":"\(id)","public_organization_data":{"id":"org_\(id)","name":"Organization \(id)","slug":null,"image_url":"","has_image":false},"status":"\(status)","created_at":1700000000000,"updated_at":1700000000000}
    """.utf8))
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let url = try args["url"]!.url()
    let query = Dictionary(grouping: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [], by: \.name).mapValues { $0.compactMap(\.value).joined(separator: ",") }
    requests.append((url.path, query))
    if let failedCollection, url.path.hasSuffix(failedCollection) {
      return .object(["status": .number(500), "headers": .object([:]), "body": .string("{\"errors\":[{\"code\":\"collection_unavailable\",\"message\":\"Unavailable\"}]}")])
    }
    let payload: JSONValue
    if url.path.hasSuffix("/accept"), url.path.contains("/organization_invitations/") {
      let id = url.deletingLastPathComponent().lastPathComponent
      payload = try invitation(id: id, status: "accepted")
      invitations = try invitations.map { value in try value.object()["id"]?.string() == id ? payload : value }
    } else if url.path.hasSuffix("/organization_invitations") {
      let pending = try invitations.filter { try $0.object()["status"]?.string() == "pending" }
      payload = paginated(pending, query: query)
    } else if url.path.hasSuffix("/organization_memberships") {
      var page = paginated(memberships, query: query)
      if let firstMembershipPageSize {
        var object = try page.object()
        object["data"] = try .array(Array(object["data"]!.array().prefix(firstMembershipPageSize)))
        page = .object(object)
        self.firstMembershipPageSize = nil
      }
      payload = page
    } else if url.path.hasSuffix("/accept"), url.path.contains("/organization_suggestions/") {
      payload = try suggestion(id: url.deletingLastPathComponent().lastPathComponent, status: "accepted")
    } else if url.path.hasSuffix("/organization_suggestions") {
      payload = paginated(suggestions, query: query)
    } else if url.path.hasSuffix("/domains") {
      payload = paginated(domains, query: query)
    } else if url.path.hasSuffix("/organization_creation_defaults") {
      payload = .object(["advisory": .null, "form": .object(["name": .string("Suggested organization"), "slug": .string("suggested"), "logo": .null, "blur_hash": .null])])
    } else { return try await base.perform(capability, arguments: arguments) }
    let envelope = JSONValue.object(["response": payload])
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(envelope), as: UTF8.self))])
  }

  private func paginated(_ values: [JSONValue], query: [String: String]) -> JSONValue {
    let offset = max(0, Int(query["offset"] ?? "0") ?? 0)
    let limit = max(1, Int(query["limit"] ?? "10") ?? 10)
    return .object(["data": .array(Array(values.dropFirst(offset).prefix(limit))), "total_count": .number(Double(values.count))])
  }
}
#endif
