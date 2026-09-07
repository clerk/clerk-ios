@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct OrganizationTests {
  init() {
    configureClerkForTesting()
  }

  private func configureOrganizationService(_ service: MockOrganizationService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      organizationService: service
    )
  }

  @Test
  func decodesOrganizationFromSnakeCaseJSON() throws {
    let json = Data(
      """
      {
        "object": "organization",
        "id": "org_123",
        "name": "Acme",
        "slug": "acme",
        "image_url": "",
        "has_image": false,
        "members_count": 0,
        "pending_invitations_count": 0,
        "max_allowed_memberships": 100,
        "admin_delete_enabled": true,
        "created_at": 0,
        "updated_at": 0,
        "public_metadata": {}
      }
      """.utf8
    )

    let organization = try JSONDecoder.clerkDecoder.decode(Organization.self, from: json)

    #expect(organization.id == "org_123")
    #expect(organization.imageUrl == "")
    #expect(!organization.hasImage)
    #expect(organization.membersCount == 0)
  }

  @Test
  func setOrganizationLogoUsesOrganizationServiceSetOrganizationLogo() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<(String, Data)?>(nil)
    let service = MockOrganizationService(setOrganizationLogo: { organizationId, imageData in
      captured.setValue((organizationId, imageData))
      return .mock
    })

    configureOrganizationService(service)

    let imageData = Data("fake image data".utf8)
    _ = try await organization.setLogo(imageData: imageData)

    let params = try #require(captured.value)
    #expect(params.0 == organization.id)
    #expect(params.1 == imageData)
  }

  @Test
  func deleteOrganizationLogoUsesOrganizationServiceDeleteOrganizationLogo() async throws {
    let organization = Organization.mock
    let capturedId = LockIsolated<String?>(nil)
    let service = MockOrganizationService(deleteOrganizationLogo: { organizationId in
      capturedId.setValue(organizationId)
      return .mock
    })

    configureOrganizationService(service)

    _ = try await organization.deleteLogo()

    #expect(capturedId.value == organization.id)
  }

  @Test
  func updateOrganizationMembershipUsesOrganizationServiceUpdateOrganizationMember() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(updateOrganizationMember: { organizationId, userId, role in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await membership.update(role: "org:admin")

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == membership.publicUserData?.userId)
    #expect(params.2 == "org:admin")
  }

  @Test
  func destroyOrganizationMembershipUsesOrganizationServiceDestroyOrganizationMembership() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(destroyOrganizationMembership: { organizationId, userId in
      captured.setValue((organizationId, userId))
      return .mockWithUserData
    })

    configureOrganizationService(service)

    _ = try await membership.destroy()

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == membership.publicUserData?.userId)
  }

  @Test
  func organizationMembershipPermissionHelpers() {
    var membership = OrganizationMembership.mockWithUserData
    membership.permissions = [
      OrganizationSystemPermission.manageProfile.rawValue,
      OrganizationSystemPermission.deleteProfile.rawValue,
      OrganizationSystemPermission.readMemberships.rawValue,
      OrganizationSystemPermission.manageDomains.rawValue,
      OrganizationSystemPermission.manageBilling.rawValue,
      "org:custom:permission",
    ]

    #expect(membership.hasPermission(.manageProfile))
    #expect(membership.hasPermission("org:custom:permission"))
    #expect(membership.canManageProfile)
    #expect(membership.canDeleteOrganization)
    #expect(membership.canReadMemberships)
    #expect(membership.canManageDomains)
    #expect(membership.canManageBilling)
    #expect(membership.canManageMemberships == false)
    #expect(membership.canReadDomains == false)
    #expect(membership.canReadBilling == false)
    #expect(membership.canReadAPIKeys == false)
    #expect(membership.canManageAPIKeys == false)

    membership.permissions = nil

    #expect(membership.hasPermission(.manageProfile) == false)
  }

  @Test
  func deleteOrganizationDomainUsesOrganizationServiceDeleteOrganizationDomain() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(deleteOrganizationDomain: { organizationId, domainId in
      captured.setValue((organizationId, domainId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.delete()

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
  }

  @Test
  func prepareAffiliationVerificationUsesOrganizationServicePrepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(prepareOrganizationDomainAffiliationVerification: { organizationId, domainId, emailAddress in
      captured.setValue((organizationId, domainId, emailAddress))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.prepareAffiliationVerification(affiliationEmailAddress: "user@example.com")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "user@example.com")
  }

  @Test
  func sendEmailCodeUsesOrganizationServicePrepareOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(prepareOrganizationDomainAffiliationVerification: { organizationId, domainId, emailAddress in
      captured.setValue((organizationId, domainId, emailAddress))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.sendEmailCode(affiliationEmailAddress: "user@example.com")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "user@example.com")
  }

  @Test
  func attemptAffiliationVerificationUsesOrganizationServiceAttemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(attemptOrganizationDomainAffiliationVerification: { organizationId, domainId, code in
      captured.setValue((organizationId, domainId, code))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.attemptAffiliationVerification(code: "123456")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "123456")
  }

  @Test
  func verifyCodeUsesOrganizationServiceAttemptOrganizationDomainAffiliationVerification() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(attemptOrganizationDomainAffiliationVerification: { organizationId, domainId, code in
      captured.setValue((organizationId, domainId, code))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == "123456")
  }

  @Test
  func organizationDomainEnrollmentModeTypeUsesTypedMode() {
    var domain = OrganizationDomain.mock
    domain.enrollmentMode = OrganizationDomain.EnrollmentMode.automaticInvitation.rawValue

    #expect(domain.enrollmentModeType == .automaticInvitation)

    domain.enrollmentMode = "future_mode"

    #expect(domain.enrollmentModeType == .unknown("future_mode"))
  }

  @Test
  func organizationDomainIsVerifiedUsesVerificationStatus() {
    var domain = OrganizationDomain.mock
    domain.verification = .init(status: "verified", strategy: "strategy", attempts: 0)

    #expect(domain.isVerified)

    domain.verification = .init(status: "unverified", strategy: "strategy", attempts: 0)

    #expect(!domain.isVerified)

    domain.verification = nil

    #expect(!domain.isVerified)
  }

  @Test
  func organizationDomainDecodesNullVerification() throws {
    let json = """
    {
      "object": "organization_domain",
      "id": "domain_1",
      "name": "example.com",
      "organization_id": "org_1",
      "enrollment_mode": "manual_invitation",
      "verification": null,
      "affiliation_email_address": null,
      "total_pending_invitations": 0,
      "total_pending_suggestions": 0,
      "created_at": 0,
      "updated_at": 0
    }
    """.data(using: .utf8)!

    let domain = try JSONDecoder.clerkDecoder.decode(OrganizationDomain.self, from: json)

    #expect(domain.verification == nil)
    #expect(!domain.isVerified)
  }

  @Test
  func updateOrganizationDomainEnrollmentModeUsesOrganizationServiceUpdateOrganizationDomainEnrollmentMode() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String, String, Bool?)?>(nil)
    let service = MockOrganizationService(updateOrganizationDomainEnrollmentMode: { organizationId, domainId, enrollmentMode, deletePending in
      captured.setValue((organizationId, domainId, enrollmentMode, deletePending))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await domain.updateEnrollmentMode(.automaticSuggestion, deletePending: true)

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
    #expect(params.2 == OrganizationDomain.EnrollmentMode.automaticSuggestion.rawValue)
    #expect(params.3 == true)
  }

  @Test
  func revokeOrganizationInvitationUsesOrganizationServiceRevokeOrganizationInvitation() async throws {
    let invitation = OrganizationInvitation.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(revokeOrganizationInvitation: { organizationId, invitationId in
      captured.setValue((organizationId, invitationId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await invitation.revoke()

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

    configureOrganizationService(service)

    _ = try await invitation.accept()

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

    configureOrganizationService(service)

    _ = try await suggestion.accept()

    #expect(captured.value == suggestion.id)
  }

  @Test
  func acceptOrganizationMembershipRequestUsesOrganizationServiceAcceptOrganizationMembershipRequest() async throws {
    let request = OrganizationMembershipRequest.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(acceptOrganizationMembershipRequest: { organizationId, requestId in
      captured.setValue((organizationId, requestId))
      return .mock
    })

    configureOrganizationService(service)

    _ = try await request.accept()

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

    configureOrganizationService(service)

    _ = try await request.reject()

    let params = try #require(captured.value)
    #expect(params.0 == request.organizationId)
    #expect(params.1 == request.id)
  }
}
