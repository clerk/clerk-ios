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

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
  }

  @Test
  func newerSearchWinsWhenAnOlderOneFinishesLast() async throws {
    stubMemberships { query, _ in
      if query == "john" {
        await gate.wait("john")
        return page(ids: ["mem_john"], totalCount: 1)
      }
      return page(ids: ["mem_1"], totalCount: 1)
    }
    let dataSource = await loadedMembers()

    dataSource.searchMembers(query: "john")
    try await waitUntil { memberRequests.queries.count == 2 }
    dataSource.searchMembers(query: "")
    await dataSource.members.refresh()
    gate.open("john")
    try await waitUntil { memberRequests.queries.count == 3 }

    #expect(dataSource.members.query == "")
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1"])
  }

  @Test
  func cancelledRefreshDuringASearchKeepsTheSearch() async throws {
    stubMemberships { query, _ in
      if query == "sam" {
        await gate.wait("sam")
        return page(ids: ["mem_sam"], totalCount: 1)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 2)
    }
    let dataSource = await loadedMembers()

    dataSource.searchMembers(query: "sam")
    try await waitUntil { memberRequests.queries.count == 2 }
    let refresh = Task { await dataSource.refreshMembers() }
    await Task.yield()
    refresh.cancel()
    gate.open("sam")
    await refresh.value
    try await waitUntil { !dataSource.members.isLoading }

    #expect(memberRequests.queries == [nil, "sam"])
    #expect(dataSource.members.query == "sam")
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_sam"])
  }

  @Test
  func repeatingTheLatestSearchOnlyReloadsAfterItFailed() async {
    let fails = LockedFlag(true)
    stubMemberships { query, _ in
      if query == "john", fails.take() {
        throw URLError(.badServerResponse)
      }
      return page(ids: query == "john" ? ["mem_john"] : ["mem_1"], totalCount: 1)
    }
    let dataSource = await loadedMembers()

    dataSource.searchMembers(query: "john")
    await dataSource.members.refresh()
    #expect(dataSource.error != nil)

    dataSource.searchMembers(query: "john")
    await dataSource.members.refresh()
    dataSource.searchMembers(query: "john")

    #expect(memberRequests.queries == [nil, "john", "john"])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func failedSearchDoesNotPageItsQueryIntoTheShownRows() async {
    stubMemberships { query, _ in
      if query == "john" {
        throw URLError(.badServerResponse)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 4)
    }
    let dataSource = await loadedMembers()

    dataSource.searchMembers(query: "john")
    await dataSource.members.refresh()
    await dataSource.members.loadMore()?.value

    #expect(memberRequests.queries == [nil, "john"])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1", "mem_2"])
  }

  @Test
  func loadMoreUsesTheSearchedQuery() async {
    stubMemberships { _, offset in
      offset == 0 ? page(ids: ["mem_1", "mem_2"], totalCount: 4) : page(ids: ["mem_3", "mem_4"], totalCount: 4)
    }
    let dataSource = await loadedMembers()
    dataSource.searchMembers(query: "john")
    await dataSource.members.refresh()

    await dataSource.members.loadMore()?.value

    #expect(memberRequests.queries == [nil, "john", "john"])
    #expect(memberRequests.offsets == [0, 0, 2])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
  }

  @Test(arguments: [false, true])
  func switchingOrganizationsDropsTheOldPages(loadMoreFails: Bool) async throws {
    stubMemberships { _, offset in
      if offset > 0 {
        await gate.wait("oldLoadMore")
        if loadMoreFails {
          throw URLError(.badServerResponse)
        }
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 4)
    }
    let store = makeStore()
    store.bind(scope("org_a", access: [.readMemberships]))
    let first = try #require(store.content(for: scope("org_a", access: [.readMemberships])))
    await first.members.refresh()
    let oldLoadMore = first.members.loadMore()

    store.bind(scope("org_b", access: [.readMemberships]))
    let second = try #require(store.content(for: scope("org_b", access: [.readMemberships])))
    await second.members.refresh()
    gate.open("oldLoadMore")
    await oldLoadMore?.value

    #expect(second.members.pager.items.map(\.id) == ["mem_1", "mem_2"])
    #expect(!second.members.pager.isLoadingMore)
    #expect(second.error == nil)
  }

  @Test(arguments: [false, true])
  func revokingAnInvitationDropsALoadMoreInFlight(loadMoreFails: Bool) async {
    let isFirstLoad = LockedFlag(true)
    stubInvitations { _, offset in
      if offset > 0 {
        await gate.wait("loadMore")
        if loadMoreFails {
          throw URLError(.badServerResponse)
        }
        return invitationPage(ids: ["inv_3", "inv_4"], totalCount: 4)
      }
      return isFirstLoad.take() ? invitationPage(ids: ["inv_1", "inv_2"], totalCount: 4) : invitationPage(ids: ["inv_2"], totalCount: 1)
    }
    stubRevoke()
    let dataSource = OrganizationMembersDataSource(scope: scope("org_a", access: [.manageMemberships]), pageSize: 2)
    dataSource.start()
    await dataSource.invitations.refresh()
    let loadMore = dataSource.invitations.loadMore()

    await dataSource.revokeInvitation(dataSource.invitations.pager.items[0])
    gate.open("loadMore")
    await loadMore?.value

    #expect(dataSource.invitations.pager.items.map(\.id) == ["inv_2"])
    #expect(dataSource.error == nil)
  }

  @Test
  func acceptingARequestReloadsMembersWithTheCurrentSearch() async {
    stubMemberships { query, _ in page(ids: query == "john" ? ["mem_john"] : ["mem_1"], totalCount: 1) }
    stubMembershipRequests { _, _ in requestPage(ids: ["req_1"], totalCount: 1) }
    stubAcceptRequest()
    let dataSource = await loadedMembers(access: [.readMemberships, .manageMemberships, .manageMembershipRequests])
    dataSource.searchMembers(query: "john")
    await dataSource.members.refresh()
    await dataSource.membershipRequests.refresh()

    await dataSource.acceptMembershipRequest(dataSource.membershipRequests.pager.items[0])

    #expect(memberRequests.queries == [nil, "john", "john"])
    #expect(dataSource.members.pager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func revokeFinishingAfterAnOrganizationSwitchLeavesTheNewOrganizationsInvitations() async throws {
    let invitationLoads = RequestLog()
    stubInvitations { organizationID, _ in
      invitationLoads.record(query: organizationID, offset: 0)
      return invitationPage(ids: ["\(organizationID)_inv"], totalCount: 1)
    }
    stubRevoke(waitingFor: "revoke")
    let store = makeStore()
    let access: OrganizationAccess = [.manageMemberships]
    store.bind(scope("org_a", access: access))
    let first = try #require(store.content(for: scope("org_a", access: access)))
    await first.invitations.refresh()
    let revoke = Task { await first.revokeInvitation(first.invitations.pager.items[0]) }
    try await waitUntil { !first.invitations.mutations.isEmpty }

    store.bind(scope("org_b", access: access))
    let second = try #require(store.content(for: scope("org_b", access: access)))
    await second.invitations.refresh()
    gate.open("revoke")
    await revoke.value

    #expect(invitationLoads.queries == ["org_a", "org_b"])
    #expect(second.invitations.pager.items.map(\.id) == ["org_b_inv"])
    #expect(second.invitations.isLoading == false)
  }

  @Test(arguments: [true, false])
  func requestDecisionFinishingAfterAnOrganizationSwitchLeavesTheNewOrganizationsLists(accepts: Bool) async throws {
    let requestLoads = RequestLog()
    stubMemberships { _, _ in page(ids: ["mem_1"], totalCount: 1) }
    stubMembershipRequests { organizationID, _ in
      requestLoads.record(query: organizationID, offset: 0)
      return requestPage(ids: ["\(organizationID)_req"], totalCount: 1)
    }
    stubAcceptRequest(waitingFor: "decision")
    stubRejectRequest(waitingFor: "decision")
    let store = makeStore()
    let access: OrganizationAccess = [.readMemberships, .manageMemberships, .manageMembershipRequests]
    store.bind(scope("org_a", access: access))
    let first = try #require(store.content(for: scope("org_a", access: access)))
    await first.membershipRequests.refresh()
    await first.members.refresh()
    let request = first.membershipRequests.pager.items[0]
    let decision = Task {
      if accepts {
        await first.acceptMembershipRequest(request)
      } else {
        await first.rejectMembershipRequest(request)
      }
    }
    try await waitUntil { !first.membershipRequests.mutations.isEmpty }

    store.bind(scope("org_b", access: access))
    let second = try #require(store.content(for: scope("org_b", access: access)))
    await second.membershipRequests.refresh()
    await second.members.refresh()
    let memberLoadsBeforeDecision = memberRequests.queries.count
    gate.open("decision")
    await decision.value

    #expect(requestLoads.queries == ["org_a", "org_b"])
    #expect(memberRequests.queries.count == memberLoadsBeforeDecision)
    #expect(second.membershipRequests.pager.items.map(\.id) == ["org_b_req"])
  }

  @Test
  func rolesLoadEveryPage() async {
    transport.stub(OrganizationAPI.getRoles(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0)) { call in
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      let ids = (offset ..< min(offset + 20, 25)).map { "role_\($0)" }
      return ClientResponse(response: rolePage(ids: ids, totalCount: 25), client: nil)
    }
    let roles = OrganizationRolesDataSource(scope: scope("org_a", access: [.readMemberships]))

    roles.start()
    await roles.refresh()

    #expect(roles.roles.count == 25)
    #expect(Set(roles.roles.map(\.id)).count == 25)
  }

  @Test
  func rolesFromBeforeAnOrganizationSwitchNeverShow() async throws {
    transport.stub(OrganizationAPI.getRoles(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0)) { [gate] call in
      let organizationID = call.path.split(separator: "/")[2]
      if organizationID == "org_a" {
        await gate.wait("rolesA")
      }
      return ClientResponse(response: rolePage(ids: ["\(organizationID)_role"], totalCount: 1), client: nil)
    }
    let store = OrganizationScopedStore { OrganizationRolesDataSource(scope: $0) }
    store.bind(scope("org_a", access: [.manageMemberships]))
    let first = try #require(store.content(for: scope("org_a", access: [.manageMemberships])))
    try await waitUntil { first.isLoading }

    store.bind(scope("org_b", access: [.manageMemberships]))
    let second = try #require(store.content(for: scope("org_b", access: [.manageMemberships])))
    await second.refresh()
    gate.open("rolesA")
    for _ in 0 ..< 100 {
      await Task.yield()
    }

    #expect(second.roles.map(\.id) == ["org_b_role"])
    #expect(first.roles.isEmpty)
  }

  private func makeStore() -> OrganizationScopedStore<OrganizationMembersDataSource> {
    OrganizationScopedStore { OrganizationMembersDataSource(scope: $0, pageSize: 2) }
  }

  private func scope(_ organizationID: String, access: OrganizationAccess) -> OrganizationScope {
    var organization = Organization.mock
    organization.id = organizationID
    return OrganizationScope(userID: User.mock.id, organization: organization, access: access)
  }

  private func loadedMembers(access: OrganizationAccess = [.readMemberships]) async -> OrganizationMembersDataSource {
    let dataSource = OrganizationMembersDataSource(scope: scope("org_a", access: access), pageSize: 2)
    dataSource.start()
    await dataSource.members.refresh()
    return dataSource
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
    _ respond: @escaping @MainActor (_ organizationID: String, _ offset: Int) async throws -> ClerkPaginatedResponse<OrganizationInvitation>
  ) {
    transport.stub(OrganizationAPI.getInvitations(
      organizationId: FakeTransport.anyPathSegment,
      offset: 0,
      pageSize: 0,
      status: []
    )) { call in
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      return try await ClientResponse(response: respond(call.organizationID, offset), client: nil)
    }
  }

  private func stubMembershipRequests(
    _ respond: @escaping @MainActor (_ organizationID: String, _ offset: Int) async throws -> ClerkPaginatedResponse<OrganizationMembershipRequest>
  ) {
    transport.stub(OrganizationAPI.getMembershipRequests(
      organizationId: FakeTransport.anyPathSegment,
      offset: 0,
      pageSize: 0,
      status: nil
    )) { call in
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      return try await ClientResponse(response: respond(call.organizationID, offset), client: nil)
    }
  }

  private func stubRevoke(waitingFor key: String? = nil) {
    transport.stub(OrganizationAPI.revokeInvitation(organizationId: FakeTransport.anyPathSegment, invitationId: FakeTransport.anyPathSegment)) { [gate] _ in
      if let key {
        await gate.wait(key)
      }
      return ClientResponse(response: OrganizationInvitation.mock, client: nil)
    }
  }

  private func stubAcceptRequest(waitingFor key: String? = nil) {
    transport.stub(OrganizationAPI.acceptMembershipRequest(organizationId: FakeTransport.anyPathSegment, requestId: FakeTransport.anyPathSegment)) { [gate] _ in
      if let key {
        await gate.wait(key)
      }
      return ClientResponse(response: OrganizationMembershipRequest.mock, client: nil)
    }
  }

  private func stubRejectRequest(waitingFor key: String) {
    transport.stub(OrganizationAPI.rejectMembershipRequest(organizationId: FakeTransport.anyPathSegment, requestId: FakeTransport.anyPathSegment)) { [gate] _ in
      await gate.wait(key)
      return ClientResponse(response: OrganizationMembershipRequest.mock, client: nil)
    }
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 1000 where !condition() {
      await Task.yield()
    }
    try #require(condition())
  }
}

extension FakeTransport.Call {
  fileprivate var organizationID: String {
    String(path.split(separator: "/")[2])
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

private func rolePage(ids: [String], totalCount: Int) -> ClerkPaginatedResponse<RoleResource> {
  ClerkPaginatedResponse(
    data: ids.map { id in
      var role = RoleResource.mock
      role.id = id
      role.key = id
      return role
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
