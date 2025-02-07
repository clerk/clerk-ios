//
//  ClerkPaginatedResponse.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation

public struct ClerkPaginatedResponse<T: Decodable & Sendable>: Decodable {
    let data: [T]
    let totalCount: Int
}
