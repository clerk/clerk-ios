//
//  OrganizationMembershipRequest.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import FactoryKit
import Foundation

/// The model that describes the request of a user to join an organization.
public struct OrganizationMembershipRequest: Codable, Sendable, Hashable, Identifiable {

  /// The unique identifier for this membership request.
  public let id: String

  /// The organization ID of the organization this request is for.
  public let organizationId: String

  /// The status of the request.
  public let status: String

  /// Public information about the user that this request belongs to.
  public let publicUserData: PublicUserData?

  /// The date when the membership request was created.
  public let createdAt: Date

  /// The date when the membership request was last updated.
  public let updatedAt: Date

  public init(
    id: String,
    organizationId: String,
    status: String,
    publicUserData: PublicUserData? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.organizationId = organizationId
    self.status = status
    self.publicUserData = publicUserData
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension OrganizationMembershipRequest {

  /// Accepts the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationMembershipRequest {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/membership_requests/\(id)/accept")
      .method(.post)
      .data(type: ClientResponse<OrganizationMembershipRequest>.self)
      .async()
      .response
  }

  /// Rejects the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func reject() async throws -> OrganizationMembershipRequest {
    try await Container.shared.apiClient().request()
      .add(path: "/v1/organizations/\(organizationId)/membership_requests/\(id)/reject")
      .method(.post)
      .data(type: ClientResponse<OrganizationMembershipRequest>.self)
      .async()
      .response
  }
}

extension OrganizationMembershipRequest {

  static var mock: Self {
    .init(
      id: "1",
      organizationId: "1",
      status: "pending",
      publicUserData: nil,
      createdAt: .distantPast,
      updatedAt: .now
    )
  }

}
