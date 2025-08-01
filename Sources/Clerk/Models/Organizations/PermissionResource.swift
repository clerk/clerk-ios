//
//  PermissionResource.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation

/// An experimental interface that includes information about a user's permission.
public struct PermissionResource: Codable, Identifiable, Sendable, Hashable {

    /// The unique identifier of the permission.
    public let id: String

    /// The unique key of the permission.
    public let key: String

    /// The name of the permission.
    public let name: String

    /// The type of the permission.
    public let type: String

    /// A description of the permission.
    public let description: String

    /// The date when the permission was created.
    public let createdAt: Date

    /// The date when the permission was last updated.
    public let updatedAt: Date

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

extension PermissionResource {

    static var mock: Self {
        .init(
            id: "1",
            key: "key",
            name: "name",
            type: "type",
            description: "description",
            createdAt: .distantPast,
            updatedAt: .now
        )
    }

}
