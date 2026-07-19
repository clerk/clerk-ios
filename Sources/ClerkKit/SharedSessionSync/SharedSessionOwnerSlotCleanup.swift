//
//  SharedSessionOwnerSlotCleanup.swift
//  Clerk
//

import Foundation

enum SharedSessionOwnerSlotCleanup {
  @MainActor
  static func deleteIfConfigured(in dependencies: any Dependencies) async throws {
    let configuration = dependencies.configurationManager
    guard configuration.options.sharedSessionSync != nil,
          let ownerIdentifier = dependencies.sharedSessionOwnerIdentifier
    else {
      return
    }

    let namespace = SharedSessionNamespace(
      frontendApiUrl: configuration.frontendApiUrl,
      publishableKey: configuration.publishableKey
    )
    let slotStore = try SharedSessionOwnerSlotStore(
      keychainConfig: configuration.options.keychainConfig,
      namespace: namespace,
      ownerIdentifier: ownerIdentifier
    )
    try await SharedSessionSlotIO(store: slotStore).deleteOwnSlot()
  }
}
