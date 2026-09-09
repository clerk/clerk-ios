//
//  AuthFlowRequestScope.swift
//  Clerk
//

import Foundation

enum AuthFlowRequestScope {
  @TaskLocal static var ownerId: UUID?

  @MainActor
  static func withOwner<T>(
    _ ownerId: UUID?,
    operation: () async throws -> T
  ) async rethrows -> T {
    try await $ownerId.withValue(ownerId, operation: operation)
  }
}
