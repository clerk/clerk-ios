//
//  OrganizationProfileVisibility.swift
//

import ClerkKit

struct OrganizationProfileVisibility: Equatable {
  let showsUpdateProfile: Bool
  let showsMembers: Bool
  let showsVerifiedDomains: Bool
  let showsLeaveOrganization: Bool
  let showsDeleteOrganization: Bool

  init(
    membership: OrganizationMembership?,
    organization: Organization?,
    organizationSettings: Clerk.Environment.OrganizationSettings?
  ) {
    showsUpdateProfile = membership?.canManageProfile == true
    showsMembers = membership?.canReadMemberships == true || membership?.canManageMemberships == true
    showsVerifiedDomains = organizationSettings?.domains.enabled == true
      && (membership?.canReadDomains == true || membership?.canManageDomains == true)
    showsLeaveOrganization = membership != nil
    showsDeleteOrganization = organizationSettings?.actions.adminDelete == true
      && organization?.adminDeleteEnabled == true
      && membership?.canDeleteOrganization == true
  }
}
