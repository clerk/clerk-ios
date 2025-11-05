//
//  OrganizationMembershipRequest.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation

/// The model that describes the request of a user to join an organization.
public struct OrganizationMembershipRequest: Codable, Sendable, Hashable, Identifiable {

  /// The unique identifier for this membership request.
  public var id: String

  /// The organization ID of the organization this request is for.
  public var organizationId: String

  /// The status of the request.
  public var status: String

  /// Public information about the user that this request belongs to.
  public var publicUserData: PublicUserData?

  /// The date when the membership request was created.
  public var createdAt: Date

  /// The date when the membership request was last updated.
  public var updatedAt: Date

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

  @MainActor
  private var organizationService: any OrganizationServiceProtocol { Clerk.shared.dependencies.organizationService }

  /// Accepts the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func accept() async throws -> OrganizationMembershipRequest {
    try await organizationService.acceptOrganizationMembershipRequest(organizationId: organizationId, requestId: id)
  }

  /// Rejects the request of a user to join the organization the request refers to.
  @discardableResult @MainActor
  public func reject() async throws -> OrganizationMembershipRequest {
    try await organizationService.rejectOrganizationMembershipRequest(organizationId: organizationId, requestId: id)
  }
}

