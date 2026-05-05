//
//  ClerkPaginatedResponse.swift
//  Clerk
//

import Foundation

/// An interface that describes the response of a method that returns a paginated list of resources.
public struct ClerkPaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
  /// An array that contains the fetched data.
  public let data: [T]

  /// The total count of data that exists remotely.
  public let totalCount: Int

  /// Indicates whether organization role updates are temporarily disabled while roles migrate.
  public let hasRoleSetMigration: Bool?

  public init(data: [T], totalCount: Int, hasRoleSetMigration: Bool? = nil) {
    self.data = data
    self.totalCount = totalCount
    self.hasRoleSetMigration = hasRoleSetMigration
  }
}
