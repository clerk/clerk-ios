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
  public let id: String

  /// The unique key of the role.
  public let key: String

  /// The name of the role.
  public let name: String

  /// The description of the role.
  public let description: String

  /// The permissions associated with the role.
  public let permissions: [PermissionResource]

  /// The date when the role was created.
  public let createdAt: Date

  /// The date when the role was last updated.
  public let updatedAt: Date

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

extension RoleResource {

  static var mock: Self {
    .init(
      id: "1",
      key: "key",
      name: "name",
      description: "description",
      permissions: [.mock],
      createdAt: .distantPast,
      updatedAt: .now
    )
  }

}
