//
//  Deletion.swift
//
//
//  Created by Mike Pitre on 7/5/24.
//

import Foundation

/// The DeletedObject class represents an item that has been deleted from the database.
public struct DeletedObject: Decodable, Sendable {
    /// The object type that has been deleted.
    let object: String?
    
    /// The ID of the deleted item.
    let id: String?
    
    /// A boolean checking if the item has been deleted or not.
    let deleted: Bool?
}
