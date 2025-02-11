//
//  ClerkPaginatedResponse.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation

/// An interface that describes the response of a method that returns a paginated list of resources.
public struct ClerkPaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    
    /// An array that contains the fetched data.
    let data: [T]
    
    /// The total count of data that exists remotely.
    let totalCount: Int
}
