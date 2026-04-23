//
//  Organizations.swift
//  Clerk
//

import Foundation

/// The main entry point for organization operations in the Clerk SDK.
///
/// Access this via `clerk.organizations` to create organizations and perform
/// organization-scoped operations.
@MainActor
public struct Organizations {
  let clerk: Clerk
  let organizationService: OrganizationServiceProtocol

  func offset(forPage page: Int, pageSize: Int) -> Int {
    max(page - 1, 0) * pageSize
  }

  /// Creates an organization and makes the current user its administrator.
  ///
  /// - Parameters:
  ///   - name: The organization name.
  ///   - slug: The optional organization slug.
  /// - Returns: The newly created ``Organization``.
  @discardableResult
  public func create(name: String, slug: String? = nil) async throws -> Organization {
    try await organizationService.createOrganization(name: name, slug: slug, sessionId: clerk.session?.id)
  }

  @discardableResult
  func update(_ organization: Organization, name: String, slug: String? = nil) async throws -> Organization {
    try await organizationService.updateOrganization(
      organizationId: organization.id,
      name: name,
      slug: slug,
      sessionId: clerk.session?.id
    )
  }

  @discardableResult
  func destroy(_ organization: Organization) async throws -> DeletedObject {
    try await organizationService.destroyOrganization(organizationId: organization.id, sessionId: clerk.session?.id)
  }

  @discardableResult
  func setLogo(for organization: Organization, imageData: Data) async throws -> Organization {
    try await organizationService.setOrganizationLogo(
      organizationId: organization.id,
      imageData: imageData,
      sessionId: clerk.session?.id
    )
  }

  func getRoles(
    for organization: Organization,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<RoleResource> {
    try await organizationService.getOrganizationRoles(
      organizationId: organization.id,
      initialPage: offset(forPage: page, pageSize: pageSize),
      pageSize: pageSize,
      sessionId: clerk.session?.id
    )
  }
}
