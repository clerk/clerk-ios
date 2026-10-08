@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationMembersDataSourceTests {
  private let transport = FakeTransport.mockDefaults()
  private let gate = ResponseGate()
  private let memberRequests = RequestLog()
  private let invitationRequests = RequestLog()

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
  }

  @Test
  func newerSearchWinsWhenAnOlderOneFinishesLast() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "john" {
        await gate.wait("john")
        return page(ids: ["mem_john"], totalCount: 1)
      }
      return page(ids: ["mem_1"], totalCount: 1)
    }
    await loadMembers(dataSource)

    dataSource.searchMembers(organization: .mock, query: "john")
    try await waitUntil { memberRequests.queries.count == 2 }
    dataSource.searchMembers(organization: .mock, query: "")
    await dataSource.members.refresh()
    gate.open("john")
    try await waitUntil { memberRequests.queries.count == 3 }

    #expect(dataSource.membershipSearchQuery == "")
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1"])
  }

  @Test
  func cancelledRefreshDuringASearchKeepsTheSearch() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "sam" {
        await gate.wait("sam")
        return page(ids: ["mem_sam"], totalCount: 1)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 2)
    }
    await loadMembers(dataSource)

    dataSource.searchMembers(organization: .mock, query: "sam")
    try await waitUntil { memberRequests.queries.count == 2 }
    let refresh = Task { await dataSource.refreshMembers(organization: .mock) }
    await Task.yield()
    refresh.cancel()
    gate.open("sam")
    await refresh.value
    try await waitUntil { !dataSource.members.isLoading }

    #expect(memberRequests.queries == [nil, "sam"])
    #expect(dataSource.membershipSearchQuery == "sam")
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_sam"])
  }

  @Test
  func repeatingTheLatestSearchOnlyReloadsAfterItFailed() async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    let fails = LockedFlag(true)
    stubMemberships { query, _ in
      if query == "john", fails.take() {
        throw URLError(.badServerResponse)
      }
      return page(ids: query == "john" ? ["mem_john"] : ["mem_1"], totalCount: 1)
    }
    await loadMembers(dataSource)

    dataSource.searchMembers(organization: .mock, query: "john")
    await dataSource.members.refresh()
    #expect(dataSource.error != nil)

    dataSource.searchMembers(organization: .mock, query: "john")
    await dataSource.members.refresh()
    dataSource.searchMembers(organization: .mock, query: "john")

    #expect(memberRequests.queries == [nil, "john", "john"])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func failedSearchDoesNotPageItsQueryIntoTheShownRows() async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "john" {
        throw URLError(.badServerResponse)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 4)
    }
    await loadMembers(dataSource)

    dataSource.searchMembers(organization: .mock, query: "john")
    await dataSource.members.refresh()
    await dataSource.members.loadMore()?.value

    #expect(memberRequests.queries == [nil, "john"])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1", "mem_2"])
  }

  @Test
  func loadMoreUsesTheSearchedQuery() async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { _, offset in
      offset == 0 ? page(ids: ["mem_1", "mem_2"], totalCount: 4) : page(ids: ["mem_3", "mem_4"], totalCount: 4)
    }
    await loadMembers(dataSource)
    dataSource.searchMembers(organization: .mock, query: "john")
    await dataSource.members.refresh()

    await dataSource.members.loadMore()?.value

    #expect(memberRequests.queries == [nil, "john", "john"])
    #expect(memberRequests.offsets == [0, 0, 2])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
  }

  @Test
  func cancellingTheInitialLoadStillLoadsTheLists() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    transport.stub(OrganizationAPI.getRoles(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0)) { [gate] _ in
      await gate.wait("roles")
      return ClientResponse(response: ClerkPaginatedResponse(data: [RoleResource.mock], totalCount: 1), client: nil)
    }
    stubMemberships { _, _ in page(ids: ["mem_1"], totalCount: 1) }

    let initialLoad = Task { await loadMembers(dataSource) }
    try await waitUntil { dataSource.members.isLoading }
    initialLoad.cancel()
    gate.open("roles")
    await initialLoad.value
    try await waitUntil { !dataSource.members.isLoading }

    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1"])
  }

  @Test(arguments: [false, true])
  func loadingAnOrganizationAgainDropsItsOldPages(loadMoreFails: Bool) async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    let isFirstLoad = LockedFlag(true)
    stubMemberships { _, offset in
      if offset > 0 {
        await gate.wait("oldLoadMore")
        if loadMoreFails {
          throw URLError(.badServerResponse)
        }
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      return isFirstLoad.take() ? page(ids: ["mem_1", "mem_2"], totalCount: 4) : page(ids: ["new_1"], totalCount: 1)
    }
    await loadMembers(dataSource)
    let oldLoadMore = dataSource.members.loadMore()

    await loadMembers(dataSource)
    gate.open("oldLoadMore")
    await oldLoadMore?.value

    #expect(dataSource.members.pager.items.map(\.id) == ["new_1"])
    #expect(!dataSource.members.pager.isLoadingMore)
    #expect(dataSource.error == nil)
  }

  @Test(arguments: [false, true])
  func revokingAnInvitationDropsALoadMoreInFlight(loadMoreFails: Bool) async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    let isFirstLoad = LockedFlag(true)
    stubInvitations { offset in
      if offset > 0 {
        await gate.wait("loadMore")
        if loadMoreFails {
          throw URLError(.badServerResponse)
        }
        return invitationPage(ids: ["inv_3", "inv_4"], totalCount: 4)
      }
      return isFirstLoad.take() ? invitationPage(ids: ["inv_1", "inv_2"], totalCount: 4) : invitationPage(ids: ["inv_2"], totalCount: 1)
    }
    transport.stub(OrganizationAPI.revokeInvitation(organizationId: FakeTransport.anyPathSegment, invitationId: FakeTransport.anyPathSegment)) { _ in
      ClientResponse(response: OrganizationInvitation.mock, client: nil)
    }
    await dataSource.loadInvitations(organization: .mock)
    let loadMore = dataSource.invitations.loadMore()

    await dataSource.revokeInvitation(dataSource.invitations.pager.items[0], organization: .mock)
    gate.open("loadMore")
    await loadMore?.value

    #expect(dataSource.invitations.pager.items.map(\.id) == ["inv_2"])
    #expect(dataSource.error == nil)
  }

  @Test
  func acceptingARequestReloadsMembersWithTheCurrentSearch() async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in page(ids: query == "john" ? ["mem_john"] : ["mem_1"], totalCount: 1) }
    stubMembershipRequests { _ in requestPage(ids: ["req_1"], totalCount: 1) }
    transport.stub(OrganizationAPI.acceptMembershipRequest(organizationId: FakeTransport.anyPathSegment, requestId: FakeTransport.anyPathSegment)) { _ in
      ClientResponse(response: OrganizationMembershipRequest.mock, client: nil)
    }
    await loadMembers(dataSource)
    dataSource.searchMembers(organization: .mock, query: "john")
    await dataSource.members.refresh()

    await dataSource.acceptMembershipRequest(.mock, organization: .mock, reloadMembers: true)

    #expect(memberRequests.queries == [nil, "john", "john"])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_john"])
  }

  private func loadMembers(_ dataSource: OrganizationMembersDataSource) async {
    await dataSource.loadInitial(
      organization: .mock,
      includeMembers: true,
      includeInvitations: false,
      includeMembershipRequests: false
    )
  }

  private func stubMemberships(
    _ respond: @escaping @MainActor (_ query: String?, _ offset: Int) async throws -> ClerkPaginatedResponse<OrganizationMembership>
  ) {
    transport.stub(OrganizationAPI.getMemberships(
      organizationId: FakeTransport.anyPathSegment,
      query: nil,
      role: nil,
      offset: 0,
      pageSize: 0
    )) { [memberRequests] call in
      let query = call.query.first { $0.name == "query" }?.value
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      memberRequests.record(query: query, offset: offset)
      return try await ClientResponse(response: respond(query, offset), client: nil)
    }
  }

  private func stubInvitations(
    _ respond: @escaping @MainActor (_ offset: Int) async throws -> ClerkPaginatedResponse<OrganizationInvitation>
  ) {
    transport.stub(OrganizationAPI.getInvitations(
      organizationId: FakeTransport.anyPathSegment,
      offset: 0,
      pageSize: 0,
      status: []
    )) { [invitationRequests] call in
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      invitationRequests.record(query: nil, offset: offset)
      return try await ClientResponse(response: respond(offset), client: nil)
    }
  }

  private func stubMembershipRequests(
    _ respond: @escaping @MainActor (_ offset: Int) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>
  ) {
    transport.stub(OrganizationAPI.getMembershipRequests(
      organizationId: FakeTransport.anyPathSegment,
      offset: 0,
      pageSize: 0,
      status: nil
    )) { call in
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      return try await ClientResponse(response: respond(offset), client: nil)
    }
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 1000 where !condition() {
      await Task.yield()
    }
    try #require(condition())
  }
}

private func page(ids: [String], totalCount: Int) -> ClerkPaginatedResponse<OrganizationMembership> {
  ClerkPaginatedResponse(
    data: ids.map { id in
      var membership = OrganizationMembership.mockWithUserData
      membership.id = id
      return membership
    },
    totalCount: totalCount
  )
}

private func invitationPage(ids: [String], totalCount: Int) -> ClerkPaginatedResponse<OrganizationInvitation> {
  ClerkPaginatedResponse(
    data: ids.map { id in
      var invitation = OrganizationInvitation.mock
      invitation.id = id
      return invitation
    },
    totalCount: totalCount
  )
}

private func requestPage(ids: [String], totalCount: Int) -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
  ClerkPaginatedResponse(
    data: ids.map { id in
      var request = OrganizationMembershipRequest.mock
      request.id = id
      return request
    },
    totalCount: totalCount
  )
}

@MainActor
private final class RequestLog {
  private(set) var queries: [String?] = []
  private(set) var offsets: [Int] = []

  func record(query: String?, offset: Int) {
    queries.append(query)
    offsets.append(offset)
  }
}

@MainActor
private final class LockedFlag {
  private var value: Bool

  init(_ value: Bool) {
    self.value = value
  }

  func take() -> Bool {
    defer { value = false }
    return value
  }
}
