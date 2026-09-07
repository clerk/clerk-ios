import Foundation

/// Clerk-provided organization system permission keys.
public enum OrganizationSystemPermission: String, Codable, CaseIterable, Sendable {
  case manageProfile = "org:sys_profile:manage"
  case deleteProfile = "org:sys_profile:delete"
  case readMemberships = "org:sys_memberships:read"
  case manageMemberships = "org:sys_memberships:manage"
  case readDomains = "org:sys_domains:read"
  case manageDomains = "org:sys_domains:manage"
  case readBilling = "org:sys_billing:read"
  case manageBilling = "org:sys_billing:manage"
  case readAPIKeys = "org:sys_api_keys:read"
  case manageAPIKeys = "org:sys_api_keys:manage"
}

extension OrganizationMembership {
  /// Returns whether the membership includes the provided organization system permission.
  public func hasPermission(_ permission: OrganizationSystemPermission) -> Bool {
    hasPermission(permission.rawValue)
  }

  /// Returns whether the membership includes the provided organization permission key.
  public func hasPermission(_ permission: String) -> Bool {
    permissionKeys.contains(permission)
  }

  public var canManageProfile: Bool {
    hasPermission(.manageProfile)
  }

  public var canDeleteOrganization: Bool {
    hasPermission(.deleteProfile)
  }

  public var canReadMemberships: Bool {
    hasPermission(.readMemberships)
  }

  public var canManageMemberships: Bool {
    hasPermission(.manageMemberships)
  }

  public var canReadDomains: Bool {
    hasPermission(.readDomains)
  }

  public var canManageDomains: Bool {
    hasPermission(.manageDomains)
  }

  public var canReadBilling: Bool {
    hasPermission(.readBilling)
  }

  public var canManageBilling: Bool {
    hasPermission(.manageBilling)
  }

  public var canReadAPIKeys: Bool {
    hasPermission(.readAPIKeys)
  }

  public var canManageAPIKeys: Bool {
    hasPermission(.manageAPIKeys)
  }

  /// Deletes the membership from the organization it belongs to.
  ///
  /// - Returns: ``OrganizationMembership``
  /// - Throws: An error if the membership deletion fails.
  @discardableResult @MainActor
  public func destroy() async throws -> OrganizationMembership {
    guard let userId = publicUserData?.userId else {
      throw ClerkClientError(message: "Unable to delete membership: missing userId", localizationBundle: .module)
    }

    return try await organization.removeMember(userId: userId)
  }

  /// Updates the member's role in the organization.
  ///
  /// - Parameter role: The role to assign to the member.
  /// - Throws: An error if the membership update fails.
  /// - Returns: ``OrganizationMembership``
  @discardableResult @MainActor
  public func update(role: String) async throws -> OrganizationMembership {
    guard let userId = publicUserData?.userId else {
      throw ClerkClientError(message: "Unable to update membership: missing userId", localizationBundle: .module)
    }

    return try await organization.updateMember(userId: userId, role: role)
  }
}
