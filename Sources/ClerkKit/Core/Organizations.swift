//
//  Organizations.swift
//  Clerk
//

import ClerkSnapshots
import Foundation

/// The main entry point for organization operations in the Clerk SDK.
///
/// Access this via `clerk.organizations` to create organizations and perform
/// organization-scoped operations.
@MainActor
public struct Organizations {
  init() {}

  /// Creates an organization and makes the current user its administrator.
  ///
  /// - Parameters:
  ///   - name: The organization name.
  ///   - slug: The optional organization slug.
  /// - Returns: The newly created ``Organization``.
  @discardableResult
  public func create(name: String, slug: String? = nil) async throws -> Organization {
    try await Clerk.js(
      .clerk,
      ClerkJSCall.createOrganization(CreateOrganizationParams(name: name, slug: slug)),
      as: Organization.self
    )
  }

  /// Retrieves an organization by its ID.
  ///
  /// - Parameter id: The organization ID.
  /// - Returns: The requested ``Organization``.
  public func get(id: String) async throws -> Organization {
    try await Clerk.js(
      .clerk,
      ClerkJSCall.getOrganization(organizationId: id),
      as: Organization.self
    )
  }
}
