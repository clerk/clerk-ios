//
//  OrganizationMembershipRequest.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Factory
import Foundation
import Get

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
}

extension OrganizationMembershipRequest {
  
  /// Accepts the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationMembershipRequest {
    let request = Request<ClientResponse<OrganizationMembershipRequest>>(
      path: "/v1/organizations/\(organizationId)/membership_requests/\(id)/accept",
      method: .post
    )
    return try await Container.shared.apiClient().send(request).value.response
  }
  
  /// Rejects the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func reject() async throws -> OrganizationMembershipRequest {
    let request = Request<ClientResponse<OrganizationMembershipRequest>>(
      path: "/v1/organizations/\(organizationId)/membership_requests/\(id)/reject",
      method: .post
    )
    return try await Container.shared.apiClient().send(request).value.response
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
