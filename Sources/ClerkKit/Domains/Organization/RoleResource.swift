//
//  RoleResource.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation

/// Represents a role with associated permissions and metadata about its creation and updates.
public struct RoleResource: Codable, Sendable, Identifiable, Hashable {
  /// The unique identifier of the role.
  public var id: String

  /// The unique key of the role.
  public var key: String

  /// The name of the role.
  public var name: String

  /// The description of the role.
  public var description: String

  /// The permissions associated with the role.
  public var permissions: [PermissionResource]

  /// The date when the role was created.
  public var createdAt: Date

  /// The date when the role was last updated.
  public var updatedAt: Date

  public init(
    id: String,
    key: String,
    name: String,
    description: String,
    permissions: [PermissionResource],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.key = key
    self.name = name
    self.description = description
    self.permissions = permissions
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
