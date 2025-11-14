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
  /// The key used to receive deviceToken in the application context.
  nonisolated private static let deviceTokenKey = "clerkDeviceToken"

  /// The key used to receive Client in the application context.
  nonisolated private static let clientKey = "clerkClient"

  /// The key used to receive Environment in the application context.
  nonisolated private static let environmentKey = "clerkEnvironment"

  /// The keychain storage used to store the received data.
  private let keychain: any KeychainStorage

  /// The WCSession instance used for communication.
  private let session: WCSession

  /// Whether we're currently processing a sync to prevent loops. Must be accessed from MainActor.
  @MainActor
  private var isProcessingSync = false

  /// Creates a new Watch Sync Receiver.
  ///
  /// - Parameter keychain: The keychain storage to store synced data in.
  init(keychain: any KeychainStorage) {
    self.keychain = keychain
    self.session = WCSession.default
    super.init()

    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  @MainActor
  private func processSyncedDeviceToken(_ deviceToken: String) {
    isProcessingSync = true
    defer { isProcessingSync = false }

    // Check if this is first sync
    let hasSyncedBefore = (try? keychain.string(forKey: "clerkDeviceTokenSynced")) == "true"
    let currentToken = try? keychain.string(forKey: "clerkDeviceToken")

    // First sync: iOS always wins if both have tokens
    if !hasSyncedBefore, currentToken != nil {
      // iOS always wins on first sync
      do {
        try keychain.set(deviceToken, forKey: "clerkDeviceToken")
        try keychain.set("true", forKey: "clerkDeviceTokenSynced")
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken from iOS app")
      }
      return
    }

    // Subsequent syncs: Always accept received value
    do {
      try keychain.set(deviceToken, forKey: "clerkDeviceToken")
      if !hasSyncedBefore {
        try keychain.set("true", forKey: "clerkDeviceTokenSynced")
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to store deviceToken from iOS app")
    }
  }

  @MainActor
  private func processSyncedClient(_ clientData: Data) {
    isProcessingSync = true
    defer { isProcessingSync = false }

    if clientData.isEmpty {
      Clerk.shared.client = nil
      return
    }

    do {
      let receivedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: clientData)
      if let currentClient = Clerk.shared.client {
        // iOS takes priority on tie, so only accept if received is newer or equal
        if receivedClient.updatedAt >= currentClient.updatedAt {
          Clerk.shared.client = receivedClient
        }
      } else {
        Clerk.shared.client = receivedClient
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to decode Client from iOS app")
    }
  }

  @MainActor
  private func processSyncedEnvironment(_ environmentData: Data) {
    isProcessingSync = true
    defer { isProcessingSync = false }

    do {
      Clerk.shared.environment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData)
    } catch {
      ClerkLogger.logError(error, message: "Failed to decode Environment from iOS app")
    }
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
      if nsError.domain == "WCErrorDomain" && nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      return
    }

    let applicationContext = session.receivedApplicationContext
    let deviceToken = applicationContext[Self.deviceTokenKey] as? String
    let clientData = applicationContext[Self.clientKey] as? Data
    let environmentData = applicationContext[Self.environmentKey] as? Data
    Task { @MainActor [weak self] in
      guard let self else { return }
      if activationState == .activated {
        if let deviceToken {
          self.processSyncedDeviceToken(deviceToken)
        }
        if let clientData {
          self.processSyncedClient(clientData)
        }
        if let environmentData {
          self.processSyncedEnvironment(environmentData)
        }
      }
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    let deviceToken = applicationContext[Self.deviceTokenKey] as? String
    let clientData = applicationContext[Self.clientKey] as? Data
    let environmentData = applicationContext[Self.environmentKey] as? Data
    Task { @MainActor [weak self] in
      guard let self else { return }
      if let deviceToken {
        self.processSyncedDeviceToken(deviceToken)
      }
      if let clientData {
        self.processSyncedClient(clientData)
      }
      if let environmentData {
        self.processSyncedEnvironment(environmentData)
      }
    }
  }
}

#endif
