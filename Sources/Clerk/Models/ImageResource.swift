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
    let id: String
    
    /// The name of the image.
    let name: String?
    
    /// The publicly accessible URL for the image.
    let publicUrl: String?
}
