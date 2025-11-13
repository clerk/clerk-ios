//
//  WatchConnectivityManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if !os(watchOS)
import WatchConnectivity

/// Manages Watch Connectivity session for syncing authentication state to companion watchOS app.
///
/// This manager handles sending the deviceToken, Client, and Environment to the watch app whenever
/// they change or when the app enters the foreground. It uses WCSession's updateApplicationContext
/// for reliable delivery even when the watch app is not running.
final class WatchConnectivityManager: NSObject, WatchConnectivitySyncing {
  /// The key used to send deviceToken in the application context.
  private static let deviceTokenKey = "clerkDeviceToken"

  /// The key used to send Client in the application context.
  private static let clientKey = "clerkClient"

  /// The key used to send Environment in the application context.
  private static let environmentKey = "clerkEnvironment"

  /// The WCSession instance used for communication.
  private let session: WCSession

  /// The keychain storage used to read the deviceToken.
  private let keychain: any KeychainStorage

  /// Whether the session is currently activated. Must be accessed from MainActor.
  @MainActor
  private var isSessionActivated = false

  /// Creates a new Watch Connectivity manager.
  ///
  /// - Parameter keychain: The keychain storage to read deviceToken from.
  init(keychain: any KeychainStorage) {
    self.session = WCSession.default
    self.keychain = keychain
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
    guard WCSession.isSupported(), isSessionActivated, session.isPaired, session.isWatchAppInstalled else {
      return
    }

    var applicationContext: [String: Any] = [:]

    if let deviceToken = try? keychain.string(forKey: "clerkDeviceToken") {
      applicationContext[Self.deviceTokenKey] = deviceToken
    }

    if let client = Clerk.shared.client {
      do {
        applicationContext[Self.clientKey] = try JSONEncoder.clerkEncoder.encode(client)
      } catch {
        ClerkLogger.logError(error, message: "Failed to serialize Client for sync")
      }
    } else {
      applicationContext[Self.clientKey] = Data()
    }

    let environment = Clerk.shared.environment
    if !environment.isEmpty {
      do {
        applicationContext[Self.environmentKey] = try JSONEncoder.clerkEncoder.encode(environment)
      } catch {
        ClerkLogger.logError(error, message: "Failed to serialize Environment for sync")
      }
    }

    guard !applicationContext.isEmpty else {
      return
    }

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
}

#if !os(watchOS)
func createWatchConnectivityManager(keychain: any KeychainStorage) -> any WatchConnectivitySyncing {
  WatchConnectivityManager(keychain: keychain)
}
#endif

extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
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
  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    Task { @MainActor in
      self.isSessionActivated = false
    }
  }

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    Task { @MainActor in
      self.session.activate()
    }
  }
  #endif
}

#endif
