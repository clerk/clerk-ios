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
}
