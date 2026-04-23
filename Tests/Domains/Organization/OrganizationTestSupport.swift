@testable import ClerkKit
import Testing

@MainActor
struct OrganizationTestSupport {
  let fixture = ClerkTestFixture()

  func makeClerk(
    organizationService: MockOrganizationService,
    environment: Clerk.Environment? = .mock,
    options: Clerk.Options = .init()
  ) throws -> Clerk {
    try fixture.makeClerk(
      organizationService: organizationService,
      options: options,
      environment: environment
    )
  }

  func makeClerk(
    organizationService: MockOrganizationService,
    options: Clerk.Options
  ) throws -> Clerk {
    try makeClerk(
      organizationService: organizationService,
      environment: .mock,
      options: options
    )
  }
}

struct OrganizationMembershipsScenario: Codable, Equatable {
  let query: String?
  let role: [String]?
}

struct OrganizationInvitationsScenario: Codable, Equatable {
  let status: String?
}

struct OrganizationDomainsScenario: Codable, Equatable {
  let enrollmentMode: String?
}

struct OrganizationMembershipRequestsScenario: Codable, Equatable {
  let status: String?
}
