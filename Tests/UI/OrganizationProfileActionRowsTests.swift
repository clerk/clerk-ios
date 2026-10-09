@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct OrganizationProfileActionRowsTests {
  @Test
  func deleteFollowsTheOrganizationsOwnSetting() {
    var organization = Organization.mock
    organization.adminDeleteEnabled = true

    // The instance default for new organizations isn't consulted.
    #expect(
      OrganizationProfileRow.actionRows(organization: organization, membership: membership(canDelete: true))
        == [.leaveOrganization, .deleteOrganization]
    )
  }

  @Test
  func deleteIsHiddenWhenTheOrganizationDisallowsIt() {
    var organization = Organization.mock
    organization.adminDeleteEnabled = false

    #expect(
      OrganizationProfileRow.actionRows(organization: organization, membership: membership(canDelete: true))
        == [.leaveOrganization]
    )
  }

  @Test
  func deleteIsHiddenWithoutTheDeletePermission() {
    #expect(
      OrganizationProfileRow.actionRows(organization: .mock, membership: membership(canDelete: false))
        == [.leaveOrganization]
    )
  }

  @Test
  func noActionsWithoutAMembership() {
    #expect(OrganizationProfileRow.actionRows(organization: .mock, membership: nil).isEmpty)
  }

  private func membership(canDelete: Bool) -> OrganizationMembership {
    var membership = OrganizationMembership.mockWithUserData
    if canDelete {
      membership.permissions = [OrganizationSystemPermission.deleteProfile.rawValue]
    }
    return membership
  }
}
