@testable import ClerkKit
@testable import ClerkKitUI
import ConcurrencyExtras
import Foundation
import XCTest

final class OrganizationAccountListDataSourceTests: XCTestCase {
  @MainActor
  func testLoadInitialFetchesResourcesAndCreationDefaults() async throws {
    configureClerkForTesting()

    let membershipCalls = LockIsolated<[(offset: Int, pageSize: Int)]>([])
    let invitationCalls = LockIsolated<[(offset: Int, pageSize: Int, status: [String])]>([])
    let suggestionCalls = LockIsolated<[(offset: Int, pageSize: Int, status: [String])]>([])
    let defaultsCalled = LockIsolated(false)
    let defaults = organizationCreationDefaults()

    let transport = FakeTransport.mockDefaults()
    transport.stubOrganizationInvitations { offset, pageSize, status in
      invitationCalls.withValue { $0.append((offset, pageSize, status)) }
      return ClerkPaginatedResponse(data: [invitation(id: "inv_1", organizationId: "org_invite")], totalCount: 1)
    }
    transport.stubOrganizationMemberships { offset, pageSize in
      membershipCalls.withValue { $0.append((offset, pageSize)) }
      return ClerkPaginatedResponse(data: [membership(id: "mem_1", organizationId: "org_member")], totalCount: 1)
    }
    transport.stubOrganizationSuggestions { offset, pageSize, status in
      suggestionCalls.withValue { $0.append((offset, pageSize, status)) }
      return ClerkPaginatedResponse(data: [suggestion(id: "sug_1", organizationId: "org_suggested")], totalCount: 1)
    }
    transport.stub(UserAPI.getOrganizationCreationDefaults()) { _ in
      defaultsCalled.setValue(true)
      return ClientResponse(response: defaults, client: nil)
    }
    setDependencies(transport: transport)

    let model = OrganizationAccountListDataSource(pageSize: 3)
    await model.loadInitial(user: .mock, includeCreationDefaults: true)

    XCTAssertFalse(model.isLoading)
    XCTAssertNil(model.error)
    XCTAssertEqual(model.membershipsPager.items.map(\.id), ["mem_1"])
    XCTAssertEqual(model.invitationsPager.items.map(\.id), ["inv_1"])
    XCTAssertEqual(model.suggestionsPager.items.map(\.id), ["sug_1"])
    XCTAssertEqual(model.creationDefaults, defaults)
    XCTAssertTrue(defaultsCalled.value)

    let membershipCall = try XCTUnwrap(membershipCalls.value.first)
    XCTAssertEqual(membershipCall.offset, 0)
    XCTAssertEqual(membershipCall.pageSize, 3)

    let invitationCall = try XCTUnwrap(invitationCalls.value.first)
    XCTAssertEqual(invitationCall.offset, 0)
    XCTAssertEqual(invitationCall.pageSize, 3)
    XCTAssertEqual(invitationCall.status, ["pending"])

    let suggestionCall = try XCTUnwrap(suggestionCalls.value.first)
    XCTAssertEqual(suggestionCall.offset, 0)
    XCTAssertEqual(suggestionCall.pageSize, 3)
    XCTAssertEqual(suggestionCall.status, ["pending", "accepted"])
  }

  @MainActor
  func testLoadInitialTracksEmptyState() async {
    configureClerkForTesting()

    let transport = FakeTransport.mockDefaults()
    transport.stubOrganizationInvitations { _, _, _ in
      ClerkPaginatedResponse(data: [], totalCount: 0)
    }
    transport.stubOrganizationMemberships { _, _ in
      ClerkPaginatedResponse(data: [], totalCount: 0)
    }
    transport.stubOrganizationSuggestions { _, _, _ in
      ClerkPaginatedResponse(data: [], totalCount: 0)
    }
    setDependencies(transport: transport)

    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: .mock, includeCreationDefaults: false)

    XCTAssertFalse(model.isLoading)
    XCTAssertFalse(model.hasExistingResources)
    XCTAssertFalse(model.hasNextPage)
    XCTAssertNil(model.creationDefaults)
  }

  @MainActor
  func testLoadInitialClearsLoadingStateAfterFailure() async {
    configureClerkForTesting()

    let transport = FakeTransport.mockDefaults()
    transport.stubOrganizationMemberships { _, _ in
      throw ClerkClientError(message: "Failed to load memberships")
    }
    setDependencies(transport: transport)

    let model = OrganizationAccountListDataSource()
    await model.loadInitial(user: .mock, includeCreationDefaults: false)

    XCTAssertFalse(model.isLoading)
    XCTAssertNotNil(model.error)
  }

  @MainActor
  func testLoadMoreMembershipsUsesCurrentOffset() async throws {
    configureClerkForTesting()

    let captured = LockIsolated<(offset: Int, pageSize: Int)?>(nil)
    let transport = FakeTransport.mockDefaults()
    transport.stubOrganizationMemberships { offset, pageSize in
      captured.setValue((offset, pageSize))
      return ClerkPaginatedResponse(
        data: [membership(id: "mem_2", organizationId: "org_member_2")],
        totalCount: 2
      )
    }
    setDependencies(transport: transport)

    let model = OrganizationAccountListDataSource(pageSize: 4)
    model.membershipsPager.replace(with: ClerkPaginatedResponse(
      data: [membership(id: "mem_1", organizationId: "org_member_1")],
      totalCount: 2
    ))

    await model.loadMoreMemberships(user: .mock)

    let params = try XCTUnwrap(captured.value)
    XCTAssertEqual(params.offset, 1)
    XCTAssertEqual(params.pageSize, 4)
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
    configureClerkForTesting()

    let capturedInvitationId = LockIsolated<String?>(nil)
    let organizationService = MockOrganizationService(acceptUserOrganizationInvitation: { invitationId in
      capturedInvitationId.setValue(invitationId)
      return invitation(id: invitationId, organizationId: "org_invite", status: "accepted")
    })
    setDependencies(organizationService: organizationService)

    let model = OrganizationAccountListDataSource()
    let pendingInvitation = invitation(id: "inv_1", organizationId: "org_invite")
    model.invitationsPager.replace(with: ClerkPaginatedResponse(data: [pendingInvitation], totalCount: 1))

    await model.acceptInvitation(pendingInvitation)

    XCTAssertEqual(capturedInvitationId.value, "inv_1")
    XCTAssertEqual(model.invitationsPager.items.first?.status, "accepted")
    XCTAssertEqual(model.invitationsPager.offset, 0)
    XCTAssertEqual(model.invitationsPager.totalCount, 0)
  }

  @MainActor
  func testAcceptInvitationKeepsPublicOrganizationDataWithoutFetchingOrganization() async throws {
    configureClerkForTesting()

    let fetchedOrganizationId = LockIsolated<String?>(nil)
    let organizationService = MockOrganizationService(
      getOrganization: { organizationId in
        fetchedOrganizationId.setValue(organizationId)
        throw ClerkClientError(message: "Accepted invitations should not fetch a full organization.")
      },
      acceptUserOrganizationInvitation: { invitationId in
        invitation(id: invitationId, organizationId: "org_invite", status: "accepted")
      }
    )
    setDependencies(organizationService: organizationService)

    let model = OrganizationAccountListDataSource()
    let pendingInvitation = invitation(id: "inv_1", organizationId: "org_invite")
    model.invitationsPager.replace(with: ClerkPaginatedResponse(data: [pendingInvitation], totalCount: 1))

    await model.acceptInvitation(pendingInvitation)

    let acceptedInvitation = try XCTUnwrap(model.invitationsPager.items.first)
    XCTAssertEqual(acceptedInvitation.status, "accepted")
    XCTAssertEqual(acceptedInvitation.publicOrganizationData.id, "org_invite")
    XCTAssertNil(fetchedOrganizationId.value)
  }

  @MainActor
  func testAcceptInvitationKeepsAcceptedRowAndUsesPendingOffsetForNextPage() async throws {
    configureClerkForTesting()

    let invitationCalls = LockIsolated<[(offset: Int, pageSize: Int, status: [String])]>([])
    let transport = FakeTransport.mockDefaults()
    transport.stubOrganizationInvitations { offset, pageSize, status in
      invitationCalls.withValue { $0.append((offset, pageSize, status)) }
      return ClerkPaginatedResponse(
        data: [invitation(id: "inv_3", organizationId: "org_3")],
        totalCount: 2
      )
    }
    let organizationService = MockOrganizationService(acceptUserOrganizationInvitation: { invitationId in
      invitation(id: invitationId, organizationId: "org_1", status: "accepted")
    })
    setDependencies(transport: transport, organizationService: organizationService)

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

    let invitationCall = try XCTUnwrap(invitationCalls.value.first)
    XCTAssertEqual(invitationCall.offset, 1)
    XCTAssertEqual(invitationCall.pageSize, 2)
    XCTAssertEqual(invitationCall.status, ["pending"])
    XCTAssertEqual(model.invitationsPager.items.map(\.id), ["inv_1", "inv_2", "inv_3"])
    XCTAssertEqual(model.invitationsPager.items.map(\.status), ["accepted", "pending", "pending"])
    XCTAssertEqual(model.invitationsPager.offset, 2)
    XCTAssertEqual(model.invitationsPager.totalCount, 2)
    XCTAssertFalse(model.invitationsPager.hasNextPage)
  }

  @MainActor
  func testAcceptSuggestionReplacesSuggestionWithAcceptedVersion() async {
    configureClerkForTesting()

    let capturedSuggestionId = LockIsolated<String?>(nil)
    let organizationService = MockOrganizationService(acceptOrganizationSuggestion: { suggestionId in
      capturedSuggestionId.setValue(suggestionId)
      return suggestion(id: suggestionId, organizationId: "org_suggested", status: "accepted")
    })
    setDependencies(organizationService: organizationService)

    let model = OrganizationAccountListDataSource()
    model.suggestionsPager.replace(with: ClerkPaginatedResponse(
      data: [suggestion(id: "sug_1", organizationId: "org_suggested")],
      totalCount: 1
    ))

    await model.acceptSuggestion(model.suggestionsPager.items[0])

    XCTAssertEqual(capturedSuggestionId.value, "sug_1")
    XCTAssertEqual(model.suggestionsPager.items.first?.status, "accepted")
  }
}

@MainActor
private func setDependencies(
  transport: FakeTransport = .mockDefaults(),
  organizationService: (any OrganizationServiceProtocol)? = nil
) {
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    transport: transport,
    organizationService: organizationService
  )
}

@MainActor
extension FakeTransport {
  fileprivate func stubOrganizationMemberships(
    _ respond: @escaping @MainActor (_ offset: Int, _ pageSize: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>
  ) {
    stub(UserAPI.getOrganizationMemberships(offset: 0, pageSize: 0)) { call in
      try await ClientResponse(response: respond(call.intQuery("offset"), call.intQuery("limit")), client: nil)
    }
  }

  fileprivate func stubOrganizationInvitations(
    _ respond: @escaping @MainActor (_ offset: Int, _ pageSize: Int, _ status: [String]) async throws -> ClerkPaginatedResponse<UserOrganizationInvitation>
  ) {
    stub(UserAPI.getOrganizationInvitations(offset: 0, pageSize: 0, status: [])) { call in
      try await ClientResponse(response: respond(call.intQuery("offset"), call.intQuery("limit"), call.statusQuery), client: nil)
    }
  }

  fileprivate func stubOrganizationSuggestions(
    _ respond: @escaping @MainActor (_ offset: Int, _ pageSize: Int, _ status: [String]) async throws -> ClerkPaginatedResponse<OrganizationSuggestion>
  ) {
    stub(UserAPI.getOrganizationSuggestions(offset: 0, pageSize: 0, status: [])) { call in
      try await ClientResponse(response: respond(call.intQuery("offset"), call.intQuery("limit"), call.statusQuery), client: nil)
    }
  }
}

extension FakeTransport.Call {
  fileprivate func intQuery(_ name: String) -> Int {
    query.first { $0.name == name }?.value.flatMap(Int.init) ?? -1
  }

  fileprivate var statusQuery: [String] {
    query.filter { $0.name == "status" }.compactMap(\.value)
  }
}

private func organization(id: String, name: String? = nil) -> Organization {
  Organization(
    id: id,
    name: name ?? id,
    slug: nil,
    imageUrl: "",
    hasImage: false,
    membersCount: nil,
    pendingInvitationsCount: nil,
    maxAllowedMemberships: 100,
    adminDeleteEnabled: true,
    createdAt: .distantPast,
    updatedAt: .now,
    publicMetadata: nil
  )
}

private func membership(id: String, organizationId: String) -> OrganizationMembership {
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
