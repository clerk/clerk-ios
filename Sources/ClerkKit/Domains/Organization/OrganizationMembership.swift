//
//  OrganizationMembership.swift
//  Clerk
//

import Foundation

/// The `OrganizationMembership` object is the model around an organization membership entity
/// and describes the relationship between users and organizations.
public struct OrganizationMembership: Codable, Equatable, Sendable, Identifiable {
  /// The unique identifier for this organization membership.
  public var id: String

  /// Metadata that can be read from the Frontend API and Backend API
  /// and can be set only from the Backend API.
  public var publicMetadata: JSON

  /// The role of the current user in the organization.
  public var role: String

  /// The formatted role name associated with this organization membership.
  public var roleName: String

  /// The permissions associated with the role.
  public var permissions: [String]?

  /// Public information about the user that this membership belongs to.
  public var publicUserData: PublicUserData?

  /// The `Organization` object the membership belongs to.
  public var organization: Organization

  /// The date when the membership was created.
  public var createdAt: Date

  /// The date when the membership was last updated.
  public var updatedAt: Date

  public init(
    id: String,
    publicMetadata: JSON,
    role: String,
    roleName: String,
    permissions: [String]?,
    publicUserData: PublicUserData? = nil,
    organization: Organization,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.publicMetadata = publicMetadata
    self.role = role
    self.roleName = roleName
    self.permissions = permissions
    self.publicUserData = publicUserData
    self.organization = organization
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

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
  @MainActor
  private var organizationService: any OrganizationServiceProtocol {
    Clerk.shared.dependencies.organizationService
  }

  /// Returns whether the membership includes the provided organization system permission.
  public func hasPermission(_ permission: OrganizationSystemPermission) -> Bool {
    hasPermission(permission.rawValue)
  }

  /// Returns whether the membership includes the provided organization permission key.
  public func hasPermission(_ permission: String) -> Bool {
    permissions?.contains(permission) == true
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
      throw ClerkClientError(message: "Unable to delete membership: missing userId")
    }

    return try await organizationService.destroyOrganizationMembership(organizationId: organization.id, userId: userId)
  }

  /// Updates the member's role in the organization.
  ///
  /// - Parameter role: The role to assign to the member.
  /// - Throws: An error if the membership update fails.
  /// - Returns: ``OrganizationMembership``
  @discardableResult @MainActor
  public func update(role: String) async throws -> OrganizationMembership {
    guard let userId = publicUserData?.userId else {
      throw ClerkClientError(message: "Unable to update membership: missing userId")
    }

    return try await organizationService.updateOrganizationMember(organizationId: organization.id, userId: userId, role: role)
  }
}
