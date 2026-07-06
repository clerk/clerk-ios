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
  /// The WCSession instance used for communication.
  private let session: WCSession

  private let payloadHandler: @MainActor (WatchSyncPayload) -> Void
  private let activationHandler: @MainActor () -> Void

  /// Whether we're currently processing a sync to prevent loops. Must be accessed from MainActor.
  @MainActor
  private var isProcessingSync = false

  /// Creates a new Watch Sync Receiver.
  init(
    payloadHandler: @escaping @MainActor (WatchSyncPayload) -> Void,
    activationHandler: @escaping @MainActor () -> Void
  ) {
    session = WCSession.default
    self.payloadHandler = payloadHandler
    self.activationHandler = activationHandler
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
    payloadHandler(payload)
  }

  /// Sends Clerk's reduced watch-sync payload to the iOS app.
  @MainActor
  package func sync(_ payload: WatchSyncPayload) {
    guard !isProcessingSync else { return }
    guard session.activationState == .activated else { return }

    let applicationContext = payload.applicationContext

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
      if activationState == .activated {
        activationHandler()
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
