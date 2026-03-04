//
//  ClientPersistenceWorker.swift
//  Clerk
//

import Foundation

/// Persists client cache updates off the MainActor while preserving write order.
actor ClientPersistenceWorker {
  private var latestAppliedSequence: UInt64 = 0

  func persist(
    client: Client?,
    sequence: UInt64,
    keychain: any KeychainStorage
  ) {
    guard sequence > latestAppliedSequence else {
      return
    }

    latestAppliedSequence = sequence

    do {
      if let client {
        let clientData = try JSONEncoder.clerkEncoder.encode(client)
        try keychain.set(clientData, forKey: ClerkKeychainKey.cachedClient.rawValue)
      } else {
        try keychain.deleteItem(forKey: ClerkKeychainKey.cachedClient.rawValue)
      }
    } catch {
      let message = if client == nil {
        "Failed to delete cached client from keychain. This is non-critical."
      } else {
        "Failed to save client to keychain. This is non-critical but may affect offline functionality."
      }
      ClerkLogger.logError(error, message: message)
    }
  }
}
