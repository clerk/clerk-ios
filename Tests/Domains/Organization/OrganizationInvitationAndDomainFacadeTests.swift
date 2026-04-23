@testable import ClerkKit
import ConcurrencyExtras
import Testing

@MainActor
@Suite(.tags(.unit))
struct OrganizationInvitationAndDomainFacadeTests {
  private let support = OrganizationTestSupport()

  @Test(
    arguments: [
      OrganizationInvitationsScenario(status: nil),
      OrganizationInvitationsScenario(status: "pending"),
    ]
  )
  func getOrganizationInvitationsUsesOrganizationServiceGetOrganizationInvitations(
    scenario: OrganizationInvitationsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationInvitations: { organizationId, initialPage, pageSize, status in
      captured.setValue((organizationId, initialPage, pageSize, status))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.getInvitations(
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
  func inviteOrganizationMemberUsesOrganizationServiceInviteOrganizationMember() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(inviteOrganizationMember: { organizationId, emailAddress, role in
      captured.setValue((organizationId, emailAddress, role))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.inviteMember(
      to: organization,
      emailAddress: "user@example.com",
      role: "org:member"
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "user@example.com")
    #expect(params.2 == "org:member")
  }

  @Test
  func createOrganizationDomainUsesOrganizationServiceCreateOrganizationDomain() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(createOrganizationDomain: { organizationId, domainName in
      captured.setValue((organizationId, domainName))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.createDomain(for: organization, domainName: "example.com")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "example.com")
  }

  @Test(
    arguments: [
      OrganizationDomainsScenario(enrollmentMode: nil),
      OrganizationDomainsScenario(enrollmentMode: "automatic"),
    ]
  )
  func getOrganizationDomainsUsesOrganizationServiceGetOrganizationDomains(
    scenario: OrganizationDomainsScenario
  ) async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Int, Int, String?)?>(nil)
    let service = MockOrganizationService(getOrganizationDomains: { organizationId, initialPage, pageSize, enrollmentMode in
      captured.setValue((organizationId, initialPage, pageSize, enrollmentMode))
      return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.getDomains(
      for: organization,
      page: 2,
      pageSize: 10,
      enrollmentMode: scenario.enrollmentMode
    )

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == 10)
    #expect(params.2 == 10)
    #expect(params.3 == scenario.enrollmentMode)
  }

  @Test
  func getOrganizationDomainUsesOrganizationServiceGetOrganizationDomain() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(getOrganizationDomain: { organizationId, domainId in
      captured.setValue((organizationId, domainId))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.getDomain(for: organization, domainId: "domain123")

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == "domain123")
  }

  @Test
  func deleteOrganizationDomainUsesOrganizationServiceDeleteOrganizationDomain() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(deleteOrganizationDomain: { organizationId, domainId in
      captured.setValue((organizationId, domainId))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.delete(domain)

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
  }

  @Test
  func sendEmailCodeUsesOrganizationServicePrepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(prepareOrganizationDomainAffiliationVerification: { organizationId, domainId, emailAddress in
      captured.setValue((organizationId, domainId, emailAddress))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.sendEmailCode(
      for: domain,
      affiliationEmailAddress: "user@example.com"
    )

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "user@example.com")
  }

  @Test
  func verifyCodeUsesOrganizationServiceAttemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(attemptOrganizationDomainAffiliationVerification: { organizationId, domainId, code in
      captured.setValue((organizationId, domainId, code))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.verifyCode("123456", for: domain)

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "123456")
  }

  @Test
  func revokeOrganizationInvitationUsesOrganizationServiceRevokeOrganizationInvitation() async throws {
    let invitation = OrganizationInvitation.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(revokeOrganizationInvitation: { organizationId, invitationId in
      captured.setValue((organizationId, invitationId))
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.revoke(invitation)

    let params = try #require(captured.value)
    #expect(params.0 == invitation.organizationId)
    #expect(params.1 == invitation.id)
  }

  @Test
  func acceptUserOrganizationInvitationUsesOrganizationServiceAcceptUserOrganizationInvitation() async throws {
    let invitation = UserOrganizationInvitation.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(acceptUserOrganizationInvitation: { invitationId in
      captured.setValue(invitationId)
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.accept(invitation)

    #expect(captured.value == invitation.id)
  }

  @Test
  func acceptOrganizationSuggestionUsesOrganizationServiceAcceptOrganizationSuggestion() async throws {
    let suggestion = OrganizationSuggestion.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(acceptOrganizationSuggestion: { suggestionId in
      captured.setValue(suggestionId)
      return .mock
    })
    let clerk = try support.makeClerk(organizationService: service)

    _ = try await clerk.organizations.accept(suggestion)

    #expect(captured.value == suggestion.id)
  }
}
