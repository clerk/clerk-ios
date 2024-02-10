//
//  ClerkImageResource.swift
//
//
//  Created by Mike Pitre on 11/28/23.
//

import Foundation

/// Represents information about an image.
public struct ClerkImageResource: Codable {
    /// The unique identifier of the image.
    var id: String
    
    /// The name of the image.
    var name: String?
    
    /// The publicly accessible URL for the image.
    var publicUrl: String?
}
