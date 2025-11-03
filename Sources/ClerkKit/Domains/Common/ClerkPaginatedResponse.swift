//
//  ClerkPaginatedResponse.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation

/// An interface that describes the response of a method that returns a paginated list of resources.
public struct ClerkPaginatedResponse<T: Codable & Sendable>: Codable, Sendable {

  /// An array that contains the fetched data.
  public let data: [T]

  /// The total count of data that exists remotely.
  public let totalCount: Int
}
