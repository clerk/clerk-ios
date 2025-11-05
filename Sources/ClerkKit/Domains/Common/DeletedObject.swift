//
//  DeletedObject.swift
//
//
//  Created by Mike Pitre on 7/5/24.
//

import Foundation

/// The DeletedObject class represents an item that has been deleted from the database.
public struct DeletedObject: Codable, Sendable {
  /// The object type that has been deleted.
  public var object: String?

  /// The ID of the deleted item.
  public var id: String?

  /// A boolean checking if the item has been deleted or not.
  public var deleted: Bool?

  public init(
    object: String? = nil,
    id: String? = nil,
    deleted: Bool? = nil
  ) {
    self.object = object
    self.id = id
    self.deleted = deleted
  }
}
