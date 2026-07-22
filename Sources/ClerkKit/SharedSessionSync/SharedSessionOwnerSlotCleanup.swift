//
//  SharedSessionOwnerSlotCleanup.swift
//  Clerk
//

import Foundation

enum SharedSessionOwnerSlotCleanup {
  @MainActor
  static func storeIfConfigured(
    in dependencies: any Dependencies
  ) throws -> SharedSessionOwnerSlotStore? {
    try SharedSessionSlotTopology(dependencies: dependencies)?
      .makeOwnerSlotStore()
  }

  @MainActor
  static func deleteIfConfigured(in dependencies: any Dependencies) async throws {
    guard let slotStore = try storeIfConfigured(in: dependencies) else { return }
    try await SharedSessionSlotIO(store: slotStore).deleteOwnSlot()
  }
}
