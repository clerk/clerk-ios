@testable import ClerkKit
import ConcurrencyExtras
import Testing

@MainActor
@Suite(.tags(.unit))
struct OrganizationMembershipRequestFacadeTests {
  private let support = OrganizationTestSupport()

  @Test(
    arguments: [
      OrganizationMembershipRequestsScenario(status: nil),
      OrganizationMembershipRequestsScenario(status: "pending"),
    ]
  )
  func getOrganizationMembershipRequestsUsesOrganizationServiceGetOrganizationMembershipRequests(
    scenario: OrganizationMembershipRequestsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationMembershipRequests: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.getMembershipRequests(
      for: organization,
      page: 2,
      pageSize: 10,
      status: scenario.status
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
    #expect(params.3 == scenario.status)
  }

  @Test
  func acceptOrganizationMembershipRequestUsesOrganizationServiceAcceptOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(acceptOrganizationMembershipRequest: { organizationId, requestId in
      captured.setValue((organizationId, requestId))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.accept(request)

    let params = try #require(captured.value)
    #expect(params.0 == request.organizationId)
    #expect(params.1 == request.id)
  }

  @Test
  func rejectOrganizationMembershipRequestUsesOrganizationServiceRejectOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(rejectOrganizationMembershipRequest: { organizationId, requestId in
      captured.setValue((organizationId, requestId))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.reject(request)

    let params = try #require(captured.value)
    #expect(params.0 == request.organizationId)
    #expect(params.1 == request.id)
  }
}
