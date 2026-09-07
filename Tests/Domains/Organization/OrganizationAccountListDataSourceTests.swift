@testable import ClerkKit
@testable import ClerkKitUI
import ClerkSnapshots
import Foundation
import XCTest

final class OrganizationAccountListDataSourceTests: XCTestCase {
  @MainActor
  func testLoadInitialFetchesResourcesAndCreationDefaults() async {
    let engine = OrganizationListEngine()
    engine.memberships = ClerkPaginatedResponse(data: [membership(id: "mem_1", organizationId: "org_member")], totalCount: 1)
    engine.invitations = ClerkPaginatedResponse(data: [invitation(id: "inv_1", organizationId: "org_invite")], totalCount: 1)
    engine.suggestions = ClerkPaginatedResponse(data: [suggestion(id: "sug_1", organizationId: "org_suggested")], totalCount: 1)
    engine.creationDefaults = organizationCreationDefaults()
    install(engine)

    let model = OrganizationAccountListDataSource(pageSize: 3)
    await model.loadInitial(user: .mock, includeCreationDefaults: true)

    XCTAssertFalse(model.isLoading)
    XCTAssertNil(model.error)
    XCTAssertEqual(model.membershipsPager.items.map(\.id), ["mem_1"])
    XCTAssertEqual(model.invitationsPager.items.map(\.id), ["inv_1"])
    XCTAssertEqual(model.suggestionsPager.items.map(\.id), ["sug_1"])
    XCTAssertEqual(model.creationDefaults, engine.creationDefaults)
    XCTAssertTrue(engine.fetchedCreationDefaults)

    XCTAssertEqual(engine.membershipPage, 1)
    XCTAssertEqual(engine.membershipPageSize, 3)
    XCTAssertEqual(engine.invitationPage, 1)
    XCTAssertEqual(engine.invitationPageSize, 3)
    XCTAssertEqual(engine.invitationStatus, .pending)
    XCTAssertEqual(engine.suggestionPage, 1)
    XCTAssertEqual(engine.suggestionPageSize, 3)
    XCTAssertEqual(engine.suggestionStatus, ["pending", "accepted"])
  }

  @MainActor
  func testLoadInitialTracksEmptyState() async {
    install(OrganizationListEngine())

    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: .mock, includeCreationDefaults: false)

    XCTAssertFalse(model.isLoading)
    XCTAssertFalse(model.hasExistingResources)
    XCTAssertFalse(model.hasNextPage)
    XCTAssertNil(model.creationDefaults)
  }

  @MainActor
  func testLoadInitialClearsLoadingStateAfterFailure() async {
    let engine = OrganizationListEngine()
    engine.membershipsError = ClerkClientError(message: "Failed to load memberships")
    install(engine)

    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: .mock, includeCreationDefaults: false)

    XCTAssertFalse(model.isLoading)
    XCTAssertNotNil(model.error)
  }

  @MainActor
  func testLoadMoreMembershipsUsesCurrentOffset() async {
    let engine = OrganizationListEngine()
    engine.memberships = ClerkPaginatedResponse(
      data: [membership(id: "mem_2", organizationId: "org_member_2")],
      totalCount: 2
    )
    install(engine)

    let model = OrganizationAccountListDataSource(pageSize: 4)
    model.membershipsPager.replace(with: ClerkPaginatedResponse(
      data: [membership(id: "mem_1", organizationId: "org_member_1")],
      totalCount: 2
    ))

    await model.loadMoreMemberships(user: .mock)

    XCTAssertEqual(engine.membershipPage, 1)
    XCTAssertEqual(engine.membershipPageSize, 4)
    XCTAssertEqual(model.membershipsPager.items.map(\.id), ["mem_1", "mem_2"])
    XCTAssertFalse(model.membershipsPager.hasNextPage)
  }

  func testPagerLoadedPageOffsetsRepresentCurrentLoadedWindow() {
    var pager = OrganizationAccountListPager<PagerItem>()

    XCTAssertEqual(pager.loadedPageOffsets(pageSize: 10), [0])

    pager.replace(with: ClerkPaginatedResponse(
      data: (1 ... 10).map { PagerItem(id: "item_\($0)") },
      totalCount: 21
    ))

    XCTAssertEqual(pager.loadedPageOffsets(pageSize: 10), [0])

    pager.append(ClerkPaginatedResponse(
      data: (11 ... 20).map { PagerItem(id: "item_\($0)") },
      totalCount: 21
    ))

    XCTAssertEqual(pager.loadedPageOffsets(pageSize: 10), [0, 10])

    pager.append(ClerkPaginatedResponse(
      data: [PagerItem(id: "item_21")],
      totalCount: 21
    ))

    XCTAssertEqual(pager.loadedPageOffsets(pageSize: 10), [0, 10, 20])
  }

  func testPagerReplaceWithPagesPreservesLoadedWindowAndPagination() {
    var pager = OrganizationAccountListPager<PagerItem>()

    pager.replace(with: [
      ClerkPaginatedResponse(
        data: (1 ... 10).map { PagerItem(id: "item_\($0)") },
        totalCount: 21
      ),
      ClerkPaginatedResponse(
        data: (11 ... 20).map { PagerItem(id: "item_\($0)") },
        totalCount: 21
      ),
    ])

    XCTAssertEqual(pager.items.map(\.id), (1 ... 20).map { "item_\($0)" })
    XCTAssertEqual(pager.offset, 20)
    XCTAssertEqual(pager.totalCount, 21)
    XCTAssertTrue(pager.hasNextPage)
  }

  @MainActor
  func testAcceptInvitationMarksInvitationSelectableAndAdjustsPagination() async {
    let engine = OrganizationListEngine()
    install(engine)

    let model = OrganizationAccountListDataSource()
    let pendingInvitation = invitation(id: "inv_1", organizationId: "org_invite")
    model.invitationsPager.replace(with: ClerkPaginatedResponse(data: [pendingInvitation], totalCount: 1))

    await model.acceptInvitation(pendingInvitation)

    XCTAssertEqual(engine.acceptedInvitationId, "inv_1")
    XCTAssertEqual(model.invitationsPager.items.first?.status, "accepted")
    XCTAssertEqual(model.invitationsPager.offset, 0)
    XCTAssertEqual(model.invitationsPager.totalCount, 0)
  }

  @MainActor
  func testAcceptInvitationKeepsPublicOrganizationDataWithoutFetchingOrganization() async throws {
    install(OrganizationListEngine())

    let model = OrganizationAccountListDataSource()
    let pendingInvitation = invitation(id: "inv_1", organizationId: "org_invite")
    model.invitationsPager.replace(with: ClerkPaginatedResponse(data: [pendingInvitation], totalCount: 1))

    await model.acceptInvitation(pendingInvitation)

    let acceptedInvitation = try XCTUnwrap(model.invitationsPager.items.first)
    XCTAssertEqual(acceptedInvitation.status, "accepted")
    XCTAssertEqual(acceptedInvitation.publicOrganizationData.id, "org_invite")
  }

  @MainActor
  func testAcceptInvitationKeepsAcceptedRowAndUsesPendingOffsetForNextPage() async {
    let engine = OrganizationListEngine()
    engine.invitations = ClerkPaginatedResponse(
      data: [invitation(id: "inv_3", organizationId: "org_3")],
      totalCount: 2
    )
    install(engine)

    let model = OrganizationAccountListDataSource(pageSize: 2)
    let firstInvitation = invitation(id: "inv_1", organizationId: "org_1")
    let secondInvitation = invitation(id: "inv_2", organizationId: "org_2")
    model.invitationsPager.replace(with: ClerkPaginatedResponse(
      data: [firstInvitation, secondInvitation],
      totalCount: 3
    ))

    await model.acceptInvitation(firstInvitation)

    XCTAssertEqual(model.invitationsPager.items.map(\.id), ["inv_1", "inv_2"])
    XCTAssertEqual(model.invitationsPager.items.map(\.status), ["accepted", "pending"])
    XCTAssertEqual(model.invitationsPager.offset, 1)
    XCTAssertEqual(model.invitationsPager.totalCount, 2)
    XCTAssertTrue(model.invitationsPager.hasNextPage)

    await model.loadMoreInvitations(user: .mock)

    XCTAssertEqual(engine.invitationPage, 1)
    XCTAssertEqual(engine.invitationPageSize, 2)
    XCTAssertEqual(engine.invitationStatus, .pending)
    XCTAssertEqual(model.invitationsPager.items.map(\.id), ["inv_1", "inv_2", "inv_3"])
    XCTAssertEqual(model.invitationsPager.items.map(\.status), ["accepted", "pending", "pending"])
    XCTAssertEqual(model.invitationsPager.offset, 2)
    XCTAssertEqual(model.invitationsPager.totalCount, 2)
    XCTAssertFalse(model.invitationsPager.hasNextPage)
  }

  @MainActor
  func testAcceptSuggestionReplacesSuggestionWithAcceptedVersion() async {
    let engine = OrganizationListEngine()
    install(engine)

    let model = OrganizationAccountListDataSource()
    model.suggestionsPager.replace(with: ClerkPaginatedResponse(
      data: [suggestion(id: "sug_1", organizationId: "org_suggested")],
      totalCount: 1
    ))

    await model.acceptSuggestion(model.suggestionsPager.items[0])

    XCTAssertEqual(engine.acceptedSuggestionId, "sug_1")
    XCTAssertEqual(model.suggestionsPager.items.first?.status, "accepted")
  }
}

@MainActor
private func install(_ engine: OrganizationListEngine) {
  configureClerkForTesting()
  Clerk.engineClient = engine
}

@MainActor
private final class OrganizationListEngine: ClerkEngineClient {
  var memberships = ClerkPaginatedResponse<ClerkKit.OrganizationMembership>(data: [], totalCount: 0)
  var invitations = ClerkPaginatedResponse<UserOrganizationInvitation>(data: [], totalCount: 0)
  var suggestions = ClerkPaginatedResponse<OrganizationSuggestion>(data: [], totalCount: 0)
  var creationDefaults: OrganizationCreationDefaults?
  var membershipsError: (any Error)?
  var membershipPage: Int?
  var membershipPageSize: Int?
  var invitationPage: Int?
  var invitationPageSize: Int?
  var invitationStatus: GetUserOrganizationInvitationsParamsStatus?
  var suggestionPage: Int?
  var suggestionPageSize: Int?
  var suggestionStatus: [String] = []
  var fetchedCreationDefaults = false
  var acceptedInvitationId: String?
  var acceptedSuggestionId: String?

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    switch invocation.method {
    case "getOrganizationMemberships":
      if let membershipsError {
        throw membershipsError
      }
      let params = try decode(GetUserOrganizationMembershipParams.self, invocation)
      membershipPage = params.initialPage
      membershipPageSize = params.pageSize
      return try encode(memberships)
    case "getOrganizationInvitations":
      let params = try decode(GetUserOrganizationInvitationsParams.self, invocation)
      invitationPage = params.initialPage
      invitationPageSize = params.pageSize
      invitationStatus = params.status
      return try encode(invitations)
    case "getOrganizationSuggestions":
      let params = try decode(GetUserOrganizationSuggestionsParams.self, invocation)
      suggestionPage = params.initialPage
      suggestionPageSize = params.pageSize
      suggestionStatus = statusStrings(params.status)
      return try encode(suggestions)
    case "getOrganizationCreationDefaults":
      fetchedCreationDefaults = true
      return try encode(creationDefaults ?? organizationCreationDefaults())
    case "accept":
      switch invocation.receiver {
      case .listed(.userOrganizationInvitation, let id):
        acceptedInvitationId = id.rawValue
        return try encode(invitation(id: id.rawValue, organizationId: "org_invite", status: "accepted"))
      case .listed(.organizationSuggestion, let id):
        acceptedSuggestionId = id.rawValue
        return try encode(suggestion(id: id.rawValue, organizationId: "org_suggested", status: "accepted"))
      default:
        throw ClerkClientError(message: "Unhandled accept receiver")
      }
    default:
      throw ClerkClientError(message: "Unhandled JS invocation \(invocation.method)")
    }
  }

  private func decode<T: Decodable>(_ type: T.Type, _ invocation: ClerkJSInvocation) throws -> T {
    try JSONDecoder().decode(type, from: (invocation.arguments.first ?? .null).data())
  }

  private func encode(_ value: some Encodable) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: JSONEncoder.clerkEncoder.encode(value))
  }

  private func statusStrings(_ value: JSONValue?) -> [String] {
    guard case .array(let values) = value else {
      if case .string(let status) = value {
        return [status]
      }
      return []
    }
    return values.compactMap { item in
      if case .string(let status) = item {
        return status
      }
      return nil
    }
  }
}

private func organization(id: String, name: String? = nil) -> Organization {
  Organization(
    object: "organization",
    id: id,
    imageUrl: "",
    hasImage: false,
    name: name ?? id,
    slug: "",
    publicMetadata: .object([:]),
    createdAt: .distantPast,
    updatedAt: .now,
    membersCount: 0,
    pendingInvitationsCount: 0,
    adminDeleteEnabled: true,
    maxAllowedMemberships: 100,
    selfServeSsoEnabled: nil,
    exclusiveMembership: nil
  )
}

private func membership(id: String, organizationId: String) -> ClerkKit.OrganizationMembership {
  OrganizationMembership(
    id: id,
    publicMetadata: "{}",
    role: "org:member",
    roleName: "Member",
    permissions: ["org:sys_memberships:read"],
    publicUserData: nil,
    organization: organization(id: organizationId),
    createdAt: .distantPast,
    updatedAt: .now
  )
}

private struct PagerItem: Codable, Identifiable {
  let id: String
}

private func invitation(
  id: String,
  organizationId: String,
  status: String = "pending"
) -> UserOrganizationInvitation {
  UserOrganizationInvitation(
    id: id,
    emailAddress: "user@example.com",
    publicOrganizationData: .init(
      hasImage: false,
      imageUrl: "",
      name: organizationId,
      id: organizationId,
      slug: nil
    ),
    publicMetadata: "{}",
    role: "org:member",
    status: status,
    createdAt: .distantPast,
    updatedAt: .now
  )
}

private func suggestion(
  id: String,
  organizationId: String,
  status: String = "pending"
) -> OrganizationSuggestion {
  OrganizationSuggestion(
    id: id,
    publicOrganizationData: .init(
      hasImage: false,
      imageUrl: "",
      name: organizationId,
      id: organizationId,
      slug: nil
    ),
    status: status,
    createdAt: .distantPast,
    updatedAt: .now
  )
}

private func organizationCreationDefaults() -> OrganizationCreationDefaults {
  OrganizationCreationDefaults(
    advisory: nil,
    form: .init(name: "Default Org", slug: "default-org", logo: nil, blurHash: nil)
  )
}
