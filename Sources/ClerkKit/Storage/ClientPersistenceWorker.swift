//
//  ClientPersistenceWorker.swift
//  Clerk
//

import Foundation

/// Persists client cache updates off the MainActor while preserving write order.
actor ClientPersistenceWorker {
  /// Tracks cache mutation ordering within the persistence worker only.
  /// This is intentionally independent from network response sequencing.
  private var latestScheduledSequence: UInt64 = 0
  private var latestCompletedSequence: UInt64 = 0
  private var waiters: [(sequence: UInt64, continuation: CheckedContinuation<Void, Never>)] = []

  func persist(
    client: Client?,
    sequence: UInt64,
    keychain: any KeychainStorage
  ) {
    guard sequence > latestScheduledSequence else {
      return
    }

    latestScheduledSequence = sequence

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

    latestCompletedSequence = max(latestCompletedSequence, sequence)
    resumeEligibleWaiters()
  }

  func waitForPersistence(upTo sequence: UInt64) async {
    guard sequence > latestCompletedSequence else {
      return
    }

    await withCheckedContinuation { continuation in
      waiters.append((sequence: sequence, continuation: continuation))
    }
  }

  private func resumeEligibleWaiters() {
    var pendingWaiters: [(sequence: UInt64, continuation: CheckedContinuation<Void, Never>)] = []

    for waiter in waiters {
      if waiter.sequence <= latestCompletedSequence {
        waiter.continuation.resume()
      } else {
        pendingWaiters.append(waiter)
      }
    }

    waiters = pendingWaiters
  }
}
