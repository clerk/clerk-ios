import ClerkKit

extension OrganizationMembership {
  var canManageProfile: Bool {
    permissions.contains("org:sys_profile:manage")
  }

  var canDeleteOrganization: Bool {
    permissions.contains("org:sys_profile:delete")
  }

  var canReadMemberships: Bool {
    permissions.contains("org:sys_memberships:read")
  }

  var canManageMemberships: Bool {
    permissions.contains("org:sys_memberships:manage")
  }

  var canReadDomains: Bool {
    permissions.contains("org:sys_domains:read")
  }

  var canManageDomains: Bool {
    permissions.contains("org:sys_domains:manage")
  }
}

extension OrganizationDomain {
  var isVerified: Bool {
    verification?.status == .verified
  }
}
