@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationMembersDataSourceTests {
  private let transport = FakeTransport.mockDefaults()
  private let gate = ResponseGate()
  private let membershipRequests = RequestCounter()
  private let invitationRequests = RequestCounter()
  private let membershipRequestRequests = RequestCounter()

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
  }

  @Test
  func searchCancelledBeforeItLoadsCanBeRetried() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    let blockFirstSearch = LockedFlag(true)
    stubMemberships { query, _ in
      if query == "john", blockFirstSearch.take() {
        try await Task.sleep(for: .seconds(60))
      }
      return page(ids: query == "john" ? ["mem_john"] : ["mem_1"], totalCount: 1)
    }

    let cancelledSearch = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 1 }
    cancelledSearch.cancel()
    await cancelledSearch.value

    #expect(dataSource.membershipSearchQuery == "")
    #expect(!dataSource.isLoadingMembers)
    #expect(dataSource.error == nil)

    await dataSource.searchMembers(organization: .mock, query: "john")

    #expect(dataSource.membershipSearchQuery == "john")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func resumeSearchRunsOnlyWhenTheFieldDiffersFromTheAppliedQuery() async {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      page(ids: query == "john" ? ["mem_john"] : ["mem_1"], totalCount: 1)
    }

    dataSource.membershipSearchText = " john "
    await dataSource.resumeSearchIfNeeded(organization: .mock)

    #expect(dataSource.membershipSearchQuery == "john")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
    #expect(membershipRequests.count == 1)

    await dataSource.resumeSearchIfNeeded(organization: .mock)

    #expect(membershipRequests.count == 1)
  }

  @Test
  func loadMoreDoesNotStartWhileTheFirstPageIsLoading() async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { _, _ in
      await gate.wait("search")
      return page(ids: ["mem_john"], totalCount: 1)
    }

    let search = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 1 }
    let loadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    for _ in 0 ..< 100 {
      await Task.yield()
    }

    #expect(membershipRequests.count == 1)

    gate.open("search")
    await search.value
    await loadMore.value
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func loadMoreThatFinishesAfterANewerSearchIsDropped() async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { query, offset in
      if offset > 0 {
        await gate.wait("loadMore")
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      return page(ids: query == "john" ? ["mem_john"] : ["mem_1", "mem_2"], totalCount: query == "john" ? 1 : 4)
    }

    let loadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    await dataSource.searchMembers(organization: .mock, query: "john")
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
    #expect(dataSource.membershipsPager.totalCount == 1)
    #expect(!dataSource.membershipsPager.hasNextPage)
  }

  @Test
  func loadMoreThatFailsAfterANewerSearchDoesNotReportItsError() async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { _, offset in
      if offset > 0 {
        await gate.wait("loadMore")
        throw URLError(.badServerResponse)
      }
      return page(ids: ["mem_john"], totalCount: 1)
    }

    let loadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    await dataSource.searchMembers(organization: .mock, query: "john")
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.error == nil)
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func refreshThatFinishesAfterANewerSearchDoesNotOverwriteIt() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == nil {
        await gate.wait("refresh")
        return page(ids: ["mem_1", "mem_2"], totalCount: 4)
      }
      return page(ids: ["mem_john"], totalCount: 1)
    }

    let refresh = Task { await dataSource.loadMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    await dataSource.searchMembers(organization: .mock, query: "john")

    #expect(!dataSource.isLoadingMembers)

    gate.open("refresh")
    await refresh.value

    #expect(dataSource.membershipSearchQuery == "john")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
    #expect(!dataSource.isLoadingMembers)
  }

  @Test
  func searchingAnEmptyQueryWhileAnotherSearchLoadsReplacesIt() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "john" {
        await gate.wait("john")
        return page(ids: ["mem_john"], totalCount: 1)
      }
      return page(ids: ["mem_1"], totalCount: 1)
    }

    let search = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 1 }
    await dataSource.searchMembers(organization: .mock, query: "")

    #expect(membershipRequests.count == 2)

    gate.open("john")
    await search.value

    #expect(dataSource.membershipSearchQuery == "")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1"])
  }

  @Test
  func refreshDuringAPendingSearchReloadsThatSearch() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "john" {
        await gate.wait("john")
        return page(ids: ["mem_john"], totalCount: 1)
      }
      return page(ids: ["mem_1"], totalCount: 1)
    }

    let search = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 1 }
    let refresh = Task { await dataSource.loadMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 2 }

    #expect(membershipRequests.queries == ["john", "john"])

    gate.open("john")
    await search.value
    await refresh.value

    #expect(dataSource.membershipSearchQuery == "john")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_john"])
  }

  @Test
  func cancelledRefreshDuringASearchDoesNotDropTheSearch() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "sam" {
        await gate.wait("sam")
        return page(ids: ["mem_sam"], totalCount: 1)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 2)
    }
    await dataSource.loadMembers(organization: .mock)
    membershipRequests.count = 0

    let search = Task { await dataSource.searchMembers(organization: .mock, query: "sam") }
    try await waitUntil { membershipRequests.count == 1 }
    let refresh = Task { await dataSource.refreshMembers(organization: .mock) }
    for _ in 0 ..< 1000 where membershipRequests.count < 2 {
      await Task.yield()
    }
    refresh.cancel()
    gate.open("sam")
    await refresh.value
    await search.value

    #expect(dataSource.membershipSearchQuery == "sam")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_sam"])
    #expect(!dataSource.isLoadingMembers)
  }

  @Test
  func cancelledSearchThatStillReturnsIsNotApplied() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { _, _ in
      await gate.wait("john")
      return page(ids: ["mem_john"], totalCount: 1)
    }

    let search = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 1 }
    search.cancel()
    gate.open("john")
    await search.value

    #expect(dataSource.membershipSearchQuery == "")
    #expect(dataSource.membershipsPager.items.isEmpty)
    #expect(!dataSource.isLoadingMembers)
  }

  @Test
  func cancelledLoadMoreThatStillReturnsIsNotAppended() async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { _, _ in
      await gate.wait("loadMore")
      return page(ids: ["mem_3", "mem_4"], totalCount: 4)
    }

    let loadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    loadMore.cancel()
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1", "mem_2"])
  }

  @Test
  func refreshAfterAbandoningAFailedSearchReloadsTheFieldsQuery() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { query, _ in
      if query == "john" {
        throw URLError(.badServerResponse)
      }
      return page(ids: ["mem_1"], totalCount: 1)
    }

    await dataSource.loadMembers(organization: .mock)
    await dataSource.searchMembers(organization: .mock, query: "john")
    try #require(dataSource.error != nil)
    await dataSource.searchMembers(organization: .mock, query: "")
    await dataSource.loadMembers(organization: .mock)

    #expect(membershipRequests.queries == [nil, "john", nil])
    #expect(dataSource.membershipSearchQuery == "")
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1"])
  }

  @Test
  func resumingAfterTheInitialLoadWasSupersededAndCancelledLoadsAgain() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { _, _ in
      await gate.wait("load")
      return page(ids: ["mem_1"], totalCount: 1)
    }

    let initialLoad = Task { await dataSource.loadMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    let resumedSearch = Task { await dataSource.resumeSearchIfNeeded(organization: .mock) }
    try await waitUntil { membershipRequests.count == 2 }
    resumedSearch.cancel()
    gate.open("load")
    await initialLoad.value
    await resumedSearch.value

    #expect(dataSource.membershipsPager.items.isEmpty)

    await dataSource.resumeSearchIfNeeded(organization: .mock)

    #expect(membershipRequests.count == 3)
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1"])
  }

  @Test
  func cancelledLoadDoesNotSupersedeANewerRequest() async throws {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { _, _ in
      await gate.wait("load")
      return page(ids: ["mem_1"], totalCount: 1)
    }

    let newerLoad = Task { await dataSource.loadMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    let cancelledLoad = Task { await dataSource.loadMembers(organization: .mock) }
    cancelledLoad.cancel()
    gate.open("load")
    await cancelledLoad.value
    await newerLoad.value

    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1"])
    #expect(!dataSource.isLoadingMembers)
  }

  @Test(arguments: [false, true])
  func loadMoreRequestedDuringARefreshRunsAfterIt(refreshFails: Bool) async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { _, offset in
      if offset > 0 {
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      await gate.wait("refresh")
      if refreshFails {
        throw URLError(.badServerResponse)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 4)
    }

    let refresh = Task { await dataSource.loadMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    await dataSource.loadMoreMembers(organization: .mock)

    #expect(membershipRequests.count == 1)

    gate.open("refresh")
    await refresh.value
    try await waitUntil { dataSource.membershipsPager.items.count == 4 }

    #expect(membershipRequests.count == 2)
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
  }

  @Test
  func loadMoreInFlightWhenASearchStartsDoesNotBlockPaginationAfterIt() async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { query, offset in
      switch (query, offset) {
      case (nil, 0):
        return page(ids: ["mem_1", "mem_2"], totalCount: 4)
      case (nil, _):
        await gate.wait("oldLoadMore")
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      case (_, 0):
        return page(ids: ["john_1", "john_2"], totalCount: 4)
      default:
        return page(ids: ["john_3", "john_4"], totalCount: 4)
      }
    }

    let oldLoadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    await dataSource.searchMembers(organization: .mock, query: "john")
    await dataSource.loadMoreMembers(organization: .mock)

    #expect(membershipRequests.count == 3)

    gate.open("oldLoadMore")
    await oldLoadMore.value
    try await waitUntil { dataSource.membershipsPager.items.count == 4 && !dataSource.membershipsPager.isLoadingMore }

    #expect(dataSource.membershipsPager.items.map(\.id) == ["john_1", "john_2", "john_3", "john_4"])
    #expect(!dataSource.membershipsPager.isLoadingMore)
  }

  @Test
  func loadMoreFromThePreviousOrganizationIsNotAppendedAfterAReset() async throws {
    let dataSource = try await dataSourceWithMorePages()
    stubMemberships { _, offset in
      if offset > 0 {
        await gate.wait("oldLoadMore")
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      return page(ids: ["new_1"], totalCount: 1)
    }
    transport.stub(OrganizationAPI.getRoles(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0)) { [gate] _ in
      await gate.wait("roles")
      return ClientResponse(response: ClerkPaginatedResponse(data: [RoleResource.mock], totalCount: 1), client: nil)
    }

    let oldLoadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    let initialLoad = Task {
      await dataSource.loadInitial(
        organization: .mock,
        includeMembers: true,
        includeInvitations: false,
        includeMembershipRequests: false
      )
    }
    try await waitUntil { dataSource.membershipsPager.items.isEmpty }
    gate.open("oldLoadMore")
    await oldLoadMore.value

    #expect(dataSource.membershipsPager.items.isEmpty)

    gate.open("roles")
    await initialLoad.value

    #expect(dataSource.membershipsPager.items.map(\.id) == ["new_1"])
  }

  @Test
  func loadMoreAbandonedByARefreshRunsAfterIt() async throws {
    let dataSource = try await dataSourceWithMorePages()
    let pageTwoRequests = RequestCounter()
    stubMemberships { [pageTwoRequests] _, offset in
      if offset == 0 {
        await gate.wait("refresh")
        return page(ids: ["mem_1", "mem_2"], totalCount: 4)
      }
      pageTwoRequests.count += 1
      if pageTwoRequests.count == 1 {
        await gate.wait("abandonedLoadMore")
      }
      return page(ids: ["mem_3", "mem_4"], totalCount: 4)
    }

    let abandonedLoadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    let refresh = Task { await dataSource.loadMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 2 }
    gate.open("abandonedLoadMore")
    await abandonedLoadMore.value
    gate.open("refresh")
    await refresh.value
    try await waitUntil { dataSource.membershipsPager.items.count == 4 }

    #expect(membershipRequests.count == 3)
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
  }

  @Test
  func returningToTheAppliedQueryRunsLoadMoreDeferredByACancelledSearch() async throws {
    let dataSource = try await dataSourceWithMorePages()
    let pageTwoRequests = RequestCounter()
    stubMemberships { [pageTwoRequests] query, offset in
      if query == "john" {
        try await Task.sleep(for: .seconds(60))
      }
      if offset > 0 {
        pageTwoRequests.count += 1
        if pageTwoRequests.count == 1 {
          await gate.wait("abandonedLoadMore")
        }
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 4)
    }

    let abandonedLoadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    let cancelledSearch = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 2 }
    cancelledSearch.cancel()
    await cancelledSearch.value
    gate.open("abandonedLoadMore")
    await abandonedLoadMore.value

    await dataSource.searchMembers(organization: .mock, query: "")
    try await waitUntil { dataSource.membershipsPager.items.count == 4 }

    #expect(pageTwoRequests.count == 2)
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
  }

  @Test
  func deferredLoadMoreSurvivesCancellingTheSearchThatRanIt() async throws {
    let dataSource = try await dataSourceWithMorePages()
    let pageTwoRequests = RequestCounter()
    stubMemberships { [pageTwoRequests] query, offset in
      if query == "john" {
        try await Task.sleep(for: .seconds(60))
      }
      if offset > 0 {
        pageTwoRequests.count += 1
        await gate.wait(pageTwoRequests.count == 1 ? "abandonedLoadMore" : "deferredLoadMore")
        return page(ids: ["mem_3", "mem_4"], totalCount: 4)
      }
      return page(ids: ["mem_1", "mem_2"], totalCount: 4)
    }

    let abandonedLoadMore = Task { await dataSource.loadMoreMembers(organization: .mock) }
    try await waitUntil { membershipRequests.count == 1 }
    let cancelledSearch = Task { await dataSource.searchMembers(organization: .mock, query: "john") }
    try await waitUntil { membershipRequests.count == 2 }
    cancelledSearch.cancel()
    await cancelledSearch.value
    let replacedSearch = Task { await dataSource.searchMembers(organization: .mock, query: "") }
    try await waitUntil { pageTwoRequests.count == 2 }
    replacedSearch.cancel()
    gate.open("abandonedLoadMore")
    gate.open("deferredLoadMore")
    await abandonedLoadMore.value
    await replacedSearch.value

    try await waitUntil { dataSource.membershipsPager.items.count == 4 }
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
  }

  @Test
  func invitationLoadMoreThatFinishesAfterARefreshIsNotAppended() async throws {
    let dataSource = try await dataSourceWithMoreInvitations()
    stubInvitations { offset in
      if offset > 0 {
        await gate.wait("loadMore")
        return invitationPage(ids: ["inv_3", "inv_4"], totalCount: 4)
      }
      return invitationPage(ids: ["new_1", "new_2"], totalCount: 2)
    }

    let loadMore = Task { await dataSource.loadMoreInvitations(organization: .mock) }
    try await waitUntil { invitationRequests.count == 1 }
    await dataSource.refreshInvitations(organization: .mock)
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.invitationsPager.items.map(\.id) == ["new_1", "new_2"])
    #expect(dataSource.invitationsPager.totalCount == 2)
    #expect(!dataSource.invitationsPager.isLoadingMore)
  }

  @Test
  func invitationLoadMoreThatFailsAfterARevokeReloadDoesNotReportItsError() async throws {
    let dataSource = try await dataSourceWithMoreInvitations()
    stubInvitations { offset in
      if offset > 0 {
        await gate.wait("loadMore")
        throw URLError(.badServerResponse)
      }
      return invitationPage(ids: ["inv_2"], totalCount: 1)
    }

    let loadMore = Task { await dataSource.loadMoreInvitations(organization: .mock) }
    try await waitUntil { invitationRequests.count == 1 }
    await dataSource.revokeInvitation(.mock, organization: .mock)
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.error == nil)
    #expect(dataSource.invitationsPager.items.map(\.id) == ["inv_2"])
  }

  @Test
  func invitationsPaginateAfterARefreshAbandonsALoadMore() async throws {
    let dataSource = try await dataSourceWithMoreInvitations()
    let pageTwoRequests = RequestCounter()
    stubInvitations { [pageTwoRequests] offset in
      switch offset {
      case 0:
        return invitationPage(ids: ["new_1", "new_2"], totalCount: 6)
      case 2:
        pageTwoRequests.count += 1
        if pageTwoRequests.count == 1 {
          await gate.wait("abandonedLoadMore")
          return invitationPage(ids: ["inv_3", "inv_4"], totalCount: 6)
        }
        return invitationPage(ids: ["new_3", "new_4"], totalCount: 6)
      default:
        return invitationPage(ids: ["new_5", "new_6"], totalCount: 6)
      }
    }

    let abandonedLoadMore = Task { await dataSource.loadMoreInvitations(organization: .mock) }
    try await waitUntil { invitationRequests.count == 1 }
    await dataSource.refreshInvitations(organization: .mock)
    try await waitUntil { dataSource.invitationsPager.items.count == 4 && !dataSource.invitationsPager.isLoadingMore }
    await dataSource.loadMoreInvitations(organization: .mock)
    gate.open("abandonedLoadMore")
    await abandonedLoadMore.value

    #expect(dataSource.invitationsPager.items.map(\.id) == ["new_1", "new_2", "new_3", "new_4", "new_5", "new_6"])
    #expect(!dataSource.invitationsPager.hasNextPage)
    #expect(!dataSource.invitationsPager.isLoadingMore)
  }

  @Test
  func invitationLoadMoreFromThePreviousOrganizationIsNotAppendedAfterAReset() async throws {
    let dataSource = try await dataSourceWithMoreInvitations()
    stubInvitations { offset in
      if offset > 0 {
        await gate.wait("oldLoadMore")
        return invitationPage(ids: ["inv_3", "inv_4"], totalCount: 4)
      }
      return invitationPage(ids: ["new_1"], totalCount: 1)
    }
    transport.stub(OrganizationAPI.getRoles(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0)) { [gate] _ in
      await gate.wait("roles")
      return ClientResponse(response: ClerkPaginatedResponse(data: [RoleResource.mock], totalCount: 1), client: nil)
    }

    let oldLoadMore = Task { await dataSource.loadMoreInvitations(organization: .mock) }
    try await waitUntil { invitationRequests.count == 1 }
    let initialLoad = Task {
      await dataSource.loadInitial(
        organization: .mock,
        includeMembers: false,
        includeInvitations: true,
        includeMembershipRequests: false
      )
    }
    try await waitUntil { dataSource.invitationsPager.items.isEmpty }
    gate.open("oldLoadMore")
    await oldLoadMore.value

    #expect(dataSource.invitationsPager.items.isEmpty)

    gate.open("roles")
    await initialLoad.value

    #expect(dataSource.invitationsPager.items.map(\.id) == ["new_1"])
  }

  @Test
  func cancelledInvitationRefreshThatFailsDoesNotReportItsError() async throws {
    let dataSource = try await dataSourceWithMoreInvitations()
    stubInvitations { _ in
      await gate.wait("refresh")
      throw URLError(.badServerResponse)
    }

    let refresh = Task { await dataSource.loadInvitations(organization: .mock) }
    try await waitUntil { invitationRequests.count == 1 }
    refresh.cancel()
    gate.open("refresh")
    await refresh.value

    #expect(dataSource.error == nil)
    #expect(dataSource.invitationsPager.items.map(\.id) == ["inv_1", "inv_2"])
    #expect(!dataSource.isLoadingInvitations)
  }

  @Test
  func cancelledInvitationLoadMoreThatFailsDoesNotReportItsError() async throws {
    let dataSource = try await dataSourceWithMoreInvitations()
    stubInvitations { _ in
      await gate.wait("loadMore")
      throw URLError(.badServerResponse)
    }

    let loadMore = Task { await dataSource.loadMoreInvitations(organization: .mock) }
    try await waitUntil { invitationRequests.count == 1 }
    loadMore.cancel()
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.error == nil)
    #expect(dataSource.invitationsPager.items.map(\.id) == ["inv_1", "inv_2"])
    #expect(!dataSource.invitationsPager.isLoadingMore)
  }

  @Test
  func membershipRequestLoadMoreThatFinishesAfterARefreshIsNotAppended() async throws {
    let dataSource = try await dataSourceWithMoreMembershipRequests()
    stubMembershipRequests { offset in
      if offset > 0 {
        await gate.wait("loadMore")
        return membershipRequestPage(ids: ["req_3", "req_4"], totalCount: 4)
      }
      return membershipRequestPage(ids: ["new_1", "new_2"], totalCount: 2)
    }

    let loadMore = Task { await dataSource.loadMoreMembershipRequests(organization: .mock) }
    try await waitUntil { membershipRequestRequests.count == 1 }
    await dataSource.loadMembershipRequests(organization: .mock)
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.membershipRequestsPager.items.map(\.id) == ["new_1", "new_2"])
    #expect(dataSource.membershipRequestsPager.totalCount == 2)
    #expect(!dataSource.membershipRequestsPager.isLoadingMore)
  }

  @Test
  func membershipRequestLoadMoreThatFailsAfterARejectReloadDoesNotReportItsError() async throws {
    let dataSource = try await dataSourceWithMoreMembershipRequests()
    stubMembershipRequests { offset in
      if offset > 0 {
        await gate.wait("loadMore")
        throw URLError(.badServerResponse)
      }
      return membershipRequestPage(ids: ["req_2"], totalCount: 1)
    }

    let loadMore = Task { await dataSource.loadMoreMembershipRequests(organization: .mock) }
    try await waitUntil { membershipRequestRequests.count == 1 }
    await dataSource.rejectMembershipRequest(.mock, organization: .mock)
    gate.open("loadMore")
    await loadMore.value

    #expect(dataSource.error == nil)
    #expect(dataSource.membershipRequestsPager.items.map(\.id) == ["req_2"])
  }

  @Test(arguments: [false, true])
  func membershipRequestLoadMoreFromThePreviousOrganizationIsIgnoredAfterAReset(fails: Bool) async throws {
    let dataSource = try await dataSourceWithMoreMembershipRequests()
    stubMembershipRequests { offset in
      if offset > 0 {
        await gate.wait("oldLoadMore")
        if fails {
          throw URLError(.badServerResponse)
        }
        return membershipRequestPage(ids: ["req_3", "req_4"], totalCount: 4)
      }
      return membershipRequestPage(ids: ["new_1"], totalCount: 1)
    }
    stubInvitations { _ in invitationPage(ids: [], totalCount: 0) }
    transport.stub(OrganizationAPI.getRoles(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0)) { [gate] _ in
      await gate.wait("roles")
      return ClientResponse(response: ClerkPaginatedResponse(data: [RoleResource.mock], totalCount: 1), client: nil)
    }

    let oldLoadMore = Task { await dataSource.loadMoreMembershipRequests(organization: .mock) }
    try await waitUntil { membershipRequestRequests.count == 1 }
    let initialLoad = Task {
      await dataSource.loadInitial(
        organization: .mock,
        includeMembers: false,
        includeInvitations: true,
        includeMembershipRequests: true
      )
    }
    try await waitUntil { dataSource.membershipRequestsPager.items.isEmpty }
    gate.open("oldLoadMore")
    await oldLoadMore.value

    #expect(dataSource.membershipRequestsPager.items.isEmpty)
    #expect(dataSource.error == nil)

    gate.open("roles")
    await initialLoad.value

    #expect(dataSource.membershipRequestsPager.items.map(\.id) == ["new_1"])
    #expect(!dataSource.membershipRequestsPager.isLoadingMore)
  }

  @Test
  func membershipRequestsPaginateAfterARefreshAbandonsALoadMore() async throws {
    let dataSource = try await dataSourceWithMoreMembershipRequests()
    let pageTwoRequests = RequestCounter()
    stubMembershipRequests { [pageTwoRequests] offset in
      switch offset {
      case 0:
        return membershipRequestPage(ids: ["new_1", "new_2"], totalCount: 6)
      case 2:
        pageTwoRequests.count += 1
        if pageTwoRequests.count == 1 {
          await gate.wait("abandonedLoadMore")
          return membershipRequestPage(ids: ["req_3", "req_4"], totalCount: 6)
        }
        return membershipRequestPage(ids: ["new_3", "new_4"], totalCount: 6)
      default:
        return membershipRequestPage(ids: ["new_5", "new_6"], totalCount: 6)
      }
    }

    let abandonedLoadMore = Task { await dataSource.loadMoreMembershipRequests(organization: .mock) }
    try await waitUntil { membershipRequestRequests.count == 1 }
    await dataSource.loadMembershipRequests(organization: .mock)
    try await waitUntil { dataSource.membershipRequestsPager.items.count == 4 && !dataSource.membershipRequestsPager.isLoadingMore }
    await dataSource.loadMoreMembershipRequests(organization: .mock)
    gate.open("abandonedLoadMore")
    await abandonedLoadMore.value

    #expect(dataSource.membershipRequestsPager.items.map(\.id) == ["new_1", "new_2", "new_3", "new_4", "new_5", "new_6"])
    #expect(!dataSource.membershipRequestsPager.hasNextPage)
    #expect(!dataSource.membershipRequestsPager.isLoadingMore)
  }

  private func dataSourceWithMorePages() async throws -> OrganizationMembersDataSource {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMemberships { _, _ in page(ids: ["mem_1", "mem_2"], totalCount: 4) }
    await dataSource.loadMembers(organization: .mock)
    try #require(dataSource.membershipsPager.hasNextPage)
    membershipRequests.count = 0
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
    )) { [membershipRequests] call in
      membershipRequests.count += 1
      membershipRequests.queries.append(call.query.first { $0.name == "query" }?.value)
      let query = call.query.first { $0.name == "query" }?.value
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      return try await ClientResponse(response: respond(query, offset), client: nil)
    }
  }

  private func dataSourceWithMoreInvitations() async throws -> OrganizationMembersDataSource {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubInvitations { _ in invitationPage(ids: ["inv_1", "inv_2"], totalCount: 4) }
    await dataSource.loadInvitations(organization: .mock)
    try #require(dataSource.invitationsPager.hasNextPage)
    invitationRequests.count = 0
    return dataSource
  }

  private func dataSourceWithMoreMembershipRequests() async throws -> OrganizationMembersDataSource {
    let dataSource = OrganizationMembersDataSource(pageSize: 2)
    stubMembershipRequests { _ in membershipRequestPage(ids: ["req_1", "req_2"], totalCount: 4) }
    await dataSource.loadMembershipRequests(organization: .mock)
    try #require(dataSource.membershipRequestsPager.hasNextPage)
    membershipRequestRequests.count = 0
    return dataSource
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
      invitationRequests.count += 1
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
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
    )) { [membershipRequestRequests] call in
      membershipRequestRequests.count += 1
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

private func membershipRequestPage(ids: [String], totalCount: Int) -> ClerkPaginatedResponse<OrganizationMembershipRequest> {
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
private final class RequestCounter {
  var count = 0
  var queries: [String?] = []
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
