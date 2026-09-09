import ClerkKit

extension Clerk {
  var shouldShowDevelopmentModeWarning: Bool {
    environment.displayConfig.showDevModeWarning && environment.displayConfig.instanceEnvironmentType != "production"
  }

  var organizationMembership: OrganizationMembership? {
    guard let organization else { return nil }
    return user?.organizationMemberships.first { $0.organization.id == organization.id }
  }
}
