//
//  OrganizationInvitation.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation

/// Represents an organization invitation and its associated details.
public struct OrganizationInvitation: Codable, Sendable, Hashable, Identifiable {

  /// The unique identifier for this organization invitation.
  public var id: String

  /// The email address the invitation has been sent to.
  public var emailAddress: String

  /// The organization ID of the organization this invitation is for.
  public var organizationId: String

  /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API.
  public var publicMetadata: JSON

  /// The role of the user in the organization.
  ///
  /// Clerk provides the default roles org:admin and org:member. However, you can create custom roles as well.
  public var role: String

  /// The status of the invitation.
  public var status: String

  /// The date when the invitation was created.
  public var createdAt: Date

  /// The date when the invitation was last updated.
  public var updatedAt: Date

  public init(
    id: String,
    emailAddress: String,
    organizationId: String,
    publicMetadata: JSON,
    role: String,
    status: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.emailAddress = emailAddress
    self.organizationId = organizationId
    self.publicMetadata = publicMetadata
    self.role = role
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension OrganizationInvitation {

  @MainActor
  private var organizationService: any OrganizationServiceProtocol { Clerk.shared.dependencies.organizationService }

  /// Revokes the invitation for the email it corresponds to.
  @discardableResult @MainActor
  public func revoke() async throws -> OrganizationInvitation {
    try await organizationService.revokeOrganizationInvitation(organizationId: organizationId, invitationId: id)
  }

}

