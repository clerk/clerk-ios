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

    #expect(membershipRequests.count == 3)
    #expect(dataSource.membershipsPager.items.map(\.id) == ["mem_1", "mem_2", "mem_3", "mem_4"])
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

@MainActor
private final class ResponseGate {
  private var continuations: [String: [CheckedContinuation<Void, Never>]] = [:]
  private var opened: Set<String> = []

  func wait(_ key: String) async {
    guard !opened.contains(key) else { return }
    await withCheckedContinuation { continuations[key, default: []].append($0) }
  }

  func open(_ key: String) {
    opened.insert(key)
    for continuation in continuations.removeValue(forKey: key) ?? [] {
      continuation.resume()
    }
  }
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
