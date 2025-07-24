//
//  OrganizationInvitation.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import FactoryKit
import Foundation
import Get

/// Represents an organization invitation and its associated details.
public struct OrganizationInvitation: Codable, Sendable, Hashable, Identifiable {

  /// The unique identifier for this organization invitation.
  public let id: String

  /// The email address the invitation has been sent to.
  public let emailAddress: String

  /// The organization ID of the organization this invitation is for.
  public let organizationId: String

  /// Metadata that can be read from the Frontend API and Backend API and can be set only from the Backend API.
  public let publicMetadata: JSON

  /// The role of the user in the organization.
  ///
  /// Clerk provides the default roles org:admin and org:member. However, you can create custom roles as well.
  public let role: String

  /// The status of the invitation.
  public let status: String

  /// The date when the invitation was created.
  public let createdAt: Date

  /// The date when the invitation was last updated.
  public let updatedAt: Date

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

  /// Revokes the invitation for the email it corresponds to.
  @discardableResult @MainActor
  public func revoke() async throws -> OrganizationInvitation {
    let request = Request<ClientResponse<OrganizationInvitation>>(
      path: "/v1/organizations/\(organizationId)/invitations/\(id)/revoke",
      method: .post
    )
    return try await Container.shared.apiClient().send(request).value.response
  }

}

extension OrganizationInvitation {

  static var mock: Self {
    .init(
      id: "1",
      emailAddress: EmailAddress.mock.emailAddress,
      organizationId: "1",
      publicMetadata: "{}",
      role: "org:member",
      status: "pending",
      createdAt: .distantPast,
      updatedAt: .now
    )
  }

}
