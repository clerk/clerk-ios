//
//  Deletion.swift
//
//
//  Created by Mike Pitre on 7/5/24.
//

import Foundation

/// The DeletedObject class represents an item that has been deleted from the database.
public struct DeletedObject: Codable, Sendable {

  /// The object type that has been deleted.
  public let object: String?

  /// The ID of the deleted item.
  public let id: String?

  /// A boolean checking if the item has been deleted or not.
  public let deleted: Bool?

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

extension DeletedObject {

  package static var mock: DeletedObject {
    .init(
      object: "object",
      id: "1",
      deleted: true
    )
  }

}
