//
//  ClerkImageResource.swift
//
//
//  Created by Mike Pitre on 11/28/23.
//

import Foundation

/// Represents information about an image.
public struct ImageResource: Codable, Sendable {

    /// The unique identifier of the image.
    public let id: String

    /// The name of the image.
    public let name: String?

    /// The publicly accessible URL for the image.
    public let publicUrl: String?

    public init(
        id: String,
        name: String? = nil,
        publicUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.publicUrl = publicUrl
    }
}
