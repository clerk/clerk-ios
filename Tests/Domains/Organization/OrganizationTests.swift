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
  func organizationMembershipPermissionHelpers() {
    var membership = OrganizationMembership.mockWithUserData
    membership.permissionKeys = [
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

    membership.permissionKeys = []

    #expect(membership.hasPermission(.manageProfile) == false)
  }

  @Test
  func organizationDomainEnrollmentModeTypeUsesTypedMode() {
    var domain = OrganizationDomain.mock
    domain.enrollmentMode = .automaticInvitation

    #expect(domain.enrollmentModeType == .automaticInvitation)

    domain.enrollmentMode = .unknown("future_mode")

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
}
