//
//  WatchSyncReceiver.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if os(watchOS)
import WatchConnectivity

/// Manages receiving synced authentication state (deviceToken, Client, Environment) from the companion iOS app via Watch Connectivity.
///
/// This receiver listens for updates from the iOS app and stores them in the watch app's keychain.
/// For Client, it implements conflict resolution using timestamps (iOS takes priority).
final class WatchSyncReceiver: NSObject, WatchConnectivitySyncing {
  /// The keychain storage used to store the received data.
  @MainActor
  private var keychain: any KeychainStorage {
    Clerk.shared.dependencies.keychain
  }

  /// The WCSession instance used for communication.
  private let session: WCSession

  /// Whether we're currently processing a sync to prevent loops. Must be accessed from MainActor.
  @MainActor
  private var isProcessingSync = false

  /// Creates a new Watch Sync Receiver.
  override init() {
    session = WCSession.default
    super.init()

    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  @MainActor
  private func applyPayload(_ payload: WatchSyncPayload) {
    isProcessingSync = true
    defer { isProcessingSync = false }
    payload.apply(from: .phone, to: Clerk.shared, keychain: keychain)
  }

  /// Syncs deviceToken, Client, and Environment to the iOS app.
  ///
  /// This method reads the deviceToken from keychain and gets Client and Environment
  /// from Clerk.shared, then sends them all together to the iOS app using
  /// updateApplicationContext for reliable delivery.
  /// Must be called from MainActor context.
  @MainActor
  package func syncAll() {
    guard !isProcessingSync else { return }
    let activationState = session.activationState
    let isReachable = session.isReachable
    guard activationState == .activated, isReachable else { return }

    let applicationContext = WatchSyncPayload(clerk: Clerk.shared, keychain: keychain).applicationContext

    guard !applicationContext.isEmpty else { return }

    do {
      try session.updateApplicationContext(applicationContext)
    } catch {
      let nsError = error as NSError
      if nsError.domain == "WCErrorDomain", nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Failed to sync data to iOS app")
    }
  }
}

extension WatchSyncReceiver: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      let nsError = error as NSError
      if nsError.domain == "WCErrorDomain", nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      return
    }

    let payload = WatchSyncPayload(applicationContext: session.receivedApplicationContext)
    Task { @MainActor [weak self] in
      guard let self else { return }
      if activationState == .activated, let payload {
        applyPayload(payload)
      }
    }
  }

  nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    let payload = WatchSyncPayload(applicationContext: applicationContext)
    Task { @MainActor [weak self] in
      guard let self else { return }
      if let payload {
        applyPayload(payload)
      }
    }
  }
}

#endif
