@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationDomainsDataSourceTests {
  private let transport = FakeTransport.mockDefaults()
  private let gate = ResponseGate()
  private let loads = DomainLoadLog()

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
    transport.stub(OrganizationAPI.getDomains(organizationId: FakeTransport.anyPathSegment, offset: 0, pageSize: 0, enrollmentMode: nil)) {
      [gate, loads] call in
      let organizationID = String(call.path.split(separator: "/")[2])
      let offset = call.query.first { $0.name == "offset" }?.value.flatMap(Int.init) ?? 0
      loads.values.append("\(organizationID)@\(offset)")
      if organizationID == "org_a", offset > 0 {
        await gate.wait("oldLoadMore")
      }
      let ids = offset == 0 ? ["\(organizationID)_1", "\(organizationID)_2"] : ["\(organizationID)_3"]
      return ClientResponse(response: domainPage(ids: ids, totalCount: 3), client: nil)
    }
  }

  @Test
  func organizationSwitchDuringALoadMoreNeverShowsTheOldOrganizationsPage() async throws {
    let store = makeStore()
    store.bind(scope("org_a"))
    let first = try #require(store.content(for: scope("org_a")))
    await first.list.refresh()
    let oldLoadMore = first.list.loadMore()

    store.bind(scope("org_b"))
    let second = try #require(store.content(for: scope("org_b")))
    await second.list.refresh()
    gate.open("oldLoadMore")
    await oldLoadMore?.value

    #expect(second.list.pager.items.map(\.id) == ["org_b_1", "org_b_2"])
    #expect(store.content(for: scope("org_a")) == nil)
  }

  @Test
  func withoutDomainAccessTheListIsEmptyAndNotLoading() {
    let domains = OrganizationDomainsDataSource(scope: scope("org_a", access: [.readMemberships]))

    domains.start()

    #expect(!domains.list.isLoading)
    #expect(domains.list.pager.items.isEmpty)
    #expect(loads.values.isEmpty)
  }

  @Test
  func domainChangedOnARetiredSourceSendsNoRequest() async {
    let domains = OrganizationDomainsDataSource(scope: scope("org_a"))
    domains.start()
    await domains.list.refresh()

    domains.retire()
    domains.domainChanged()
    for _ in 0 ..< 100 {
      await Task.yield()
    }

    #expect(loads.values == ["org_a@0"])
  }

  @Test
  func deleteFinishingAfterAnOrganizationSwitchLeavesTheNewOrganizationsDomains() async throws {
    let store = makeStore()
    store.bind(scope("org_a"))
    let first = try #require(store.content(for: scope("org_a")))
    await first.list.refresh()
    let deleted = first.list.pager.items[0]

    store.bind(scope("org_b"))
    let second = try #require(store.content(for: scope("org_b")))
    await second.list.refresh()
    await first.domainDeleted(deleted)

    #expect(second.list.pager.items.map(\.id) == ["org_b_1", "org_b_2"])
    #expect(second.list.pager.totalCount == 3)
  }

  private func makeStore() -> OrganizationScopedStore<OrganizationDomainsDataSource> {
    OrganizationScopedStore { OrganizationDomainsDataSource(scope: $0, pageSize: 2) }
  }

  private func scope(_ organizationID: String, access: OrganizationAccess = [.readDomains, .manageDomains]) -> OrganizationScope {
    var organization = Organization.mock
    organization.id = organizationID
    return OrganizationScope(userID: User.mock.id, organization: organization, access: access)
  }
}

private func domainPage(ids: [String], totalCount: Int) -> ClerkPaginatedResponse<OrganizationDomain> {
  ClerkPaginatedResponse(
    data: ids.map { id in
      var domain = OrganizationDomain.mock
      domain.id = id
      return domain
    },
    totalCount: totalCount
  )
}

@MainActor
private final class DomainLoadLog {
  var values: [String] = []
}
