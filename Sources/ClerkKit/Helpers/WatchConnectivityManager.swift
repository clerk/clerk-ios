//
//  WatchConnectivityManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if os(iOS)
import WatchConnectivity

/// Manages Watch Connectivity session for syncing authentication state to companion watchOS app.
///
/// This manager handles sending the deviceToken, Client, and Environment to the watch app whenever
/// they change or when the app enters the foreground. It uses WCSession's updateApplicationContext
/// for reliable delivery even when the watch app is not running.
final class WatchConnectivityManager: NSObject, WatchConnectivitySyncing {
  /// The WCSession instance used for communication.
  private let session: WCSession

  /// The keychain storage used to read the deviceToken.
  @MainActor
  private var keychain: any KeychainStorage {
    Clerk.shared.dependencies.keychain
  }

  /// Whether the session is currently activated. Must be accessed from MainActor.
  @MainActor
  private var isSessionActivated = false

  /// Whether we're currently processing a sync to prevent loops. Must be accessed from MainActor.
  @MainActor
  private var isProcessingSync = false

  /// Creates a new Watch Connectivity manager.
  override init() {
    session = WCSession.default
    super.init()

    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  /// Syncs deviceToken, Client, and Environment to the watch app.
  ///
  /// This method reads the deviceToken from keychain and gets Client and Environment
  /// from Clerk.shared, then sends them all together to the watch app using
  /// updateApplicationContext for reliable delivery.
  /// Must be called from MainActor context.
  @MainActor
  func syncAll() {
    guard !isProcessingSync else { return }
    guard isSessionActivated, session.isPaired, session.isWatchAppInstalled else { return }

    let applicationContext = WatchSyncPayload(clerk: Clerk.shared, keychain: keychain).applicationContext

    guard !applicationContext.isEmpty else { return }

    do {
      try session.updateApplicationContext(applicationContext)
    } catch {
      let nsError = error as NSError
      if nsError.domain == "WCErrorDomain", nsError.code == 7006 || nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Failed to sync data to watch app")
    }
  }

  @MainActor
  private func applyPayload(_ payload: WatchSyncPayload) {
    isProcessingSync = true
    defer { isProcessingSync = false }
    payload.apply(from: .watch, to: Clerk.shared, keychain: keychain)
  }
}

#if os(iOS)
@MainActor
func createWatchConnectivityManager() -> any WatchConnectivitySyncing {
  WatchConnectivityManager()
}
#endif

extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated func session(
    _: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      return
    }

    Task { @MainActor in
      self.isSessionActivated = activationState == .activated
      if self.isSessionActivated {
        self.syncAll()
      }
    }
  }

  #if os(iOS)
  nonisolated func sessionDidBecomeInactive(_: WCSession) {
    Task { @MainActor in
      self.isSessionActivated = false
    }
  }

  nonisolated func sessionDidDeactivate(_: WCSession) {
    Task { @MainActor in
      self.session.activate()
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
  #endif
}

#endif
