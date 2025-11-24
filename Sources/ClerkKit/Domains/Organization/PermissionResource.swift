//
//  PermissionResource.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation

/// An experimental interface that includes information about a user's permission.
public struct PermissionResource: Codable, Identifiable, Sendable {
  /// The unique identifier of the permission.
  public var id: String

  /// The unique key of the permission.
  public var key: String

  /// The name of the permission.
  public var name: String

  /// The type of the permission.
  public var type: String

  /// A description of the permission.
  public var description: String

  /// The date when the permission was created.
  public var createdAt: Date

  /// The date when the permission was last updated.
  public var updatedAt: Date

  public init(
    id: String,
    key: String,
    name: String,
    type: String,
    description: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.key = key
    self.name = name
    self.type = type
    self.description = description
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
