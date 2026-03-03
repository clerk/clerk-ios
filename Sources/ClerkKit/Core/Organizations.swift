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
  private let organizationService: OrganizationServiceProtocol

  init(organizationService: OrganizationServiceProtocol) {
    self.organizationService = organizationService
  }

  /// Creates an organization and makes the current user its administrator.
  ///
  /// - Parameter name: The organization name.
  /// - Returns: The newly created ``Organization``.
  @discardableResult
  public func create(name: String) async throws -> Organization {
    try await organizationService.createOrganization(name: name)
  }
}
