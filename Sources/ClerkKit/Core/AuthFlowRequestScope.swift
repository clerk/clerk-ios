//
//  AuthFlowRequestScope.swift
//  Clerk
//

import Foundation

package enum AuthFlowRequestScope {
  @TaskLocal static var ownerId: UUID?

  @MainActor
  package static func withOwner<T>(
    _ ownerId: UUID?,
    operation: () async throws -> T
  ) async rethrows -> T {
    try await $ownerId.withValue(ownerId, operation: operation)
  }
}
