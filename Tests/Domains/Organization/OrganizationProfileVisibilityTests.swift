@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@Suite(.serialized)
struct OrganizationProfileVisibilityTests {
  @Test
  func showsRowsAllowedByMembershipPermissionsAndSettings() {
    var settings = Clerk.Environment.OrganizationSettings.mock
    settings.domains.enabled = true

    let visibility = OrganizationProfileVisibility(
      membership: membership(permissions: [
        .manageProfile,
        .manageMemberships,
        .manageDomains,
        .deleteProfile,
      ]),
      organization: .mock,
      organizationSettings: settings
    )

    #expect(visibility.showsUpdateProfile)
    #expect(visibility.showsMembers)
    #expect(visibility.showsVerifiedDomains)
    #expect(visibility.showsLeaveOrganization)
    #expect(visibility.showsDeleteOrganization)
  }

  @Test
  func hidesRowsWhenMembershipIsMissing() {
    var settings = Clerk.Environment.OrganizationSettings.mock
    settings.domains.enabled = true

    let visibility = OrganizationProfileVisibility(
      membership: nil,
      organization: .mock,
      organizationSettings: settings
    )

    #expect(!visibility.showsUpdateProfile)
    #expect(!visibility.showsMembers)
    #expect(!visibility.showsVerifiedDomains)
    #expect(!visibility.showsLeaveOrganization)
    #expect(!visibility.showsDeleteOrganization)
  }

  @Test
  func hidesVerifiedDomainsWhenDomainsAreDisabled() {
    var settings = Clerk.Environment.OrganizationSettings.mock
    settings.domains.enabled = false

    let visibility = OrganizationProfileVisibility(
      membership: membership(permissions: [.readDomains]),
      organization: .mock,
      organizationSettings: settings
    )

    #expect(!visibility.showsVerifiedDomains)
  }

  @Test
  func hidesDeleteWhenSettingsOrOrganizationDisallowIt() {
    var settings = Clerk.Environment.OrganizationSettings.mock
    settings.actions.adminDelete = false
    var organization = Organization.mock
    organization.adminDeleteEnabled = true

    var visibility = OrganizationProfileVisibility(
      membership: membership(permissions: [.deleteProfile]),
      organization: organization,
      organizationSettings: settings
    )

    #expect(!visibility.showsDeleteOrganization)

    settings.actions.adminDelete = true
    organization.adminDeleteEnabled = false
    visibility = OrganizationProfileVisibility(
      membership: membership(permissions: [.deleteProfile]),
      organization: organization,
      organizationSettings: settings
    )

    #expect(!visibility.showsDeleteOrganization)
  }
}

private func membership(permissions: [OrganizationSystemPermission]) -> OrganizationMembership {
  var membership = OrganizationMembership.mockWithUserData
  membership.permissions = permissions.map(\.rawValue)
  return membership
}
