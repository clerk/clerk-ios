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
final class WatchSyncReceiver: NSObject {
  /// The key used to receive deviceToken in the application context.
  private static let deviceTokenKey = "clerkDeviceToken"

  /// The key used to receive Client in the application context.
  private static let clientKey = "clerkClient"

  /// The key used to receive Environment in the application context.
  private static let environmentKey = "clerkEnvironment"

  /// The keychain storage used to store the received data.
  private let keychain: any KeychainStorage

  /// The WCSession instance used for communication.
  private let session: WCSession

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
  private func storeDeviceToken(_ deviceToken: String) {
    do {
      try keychain.set(deviceToken, forKey: "clerkDeviceToken")
    } catch {
      ClerkLogger.logError(error, message: "Failed to store deviceToken from iOS app")
    }
  }

  @MainActor
  private func processSyncedClient(_ clientData: Data) {
    if clientData.isEmpty {
      Clerk.shared.client = nil
      return
    }

    do {
      let receivedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: clientData)
      if let currentClient = Clerk.shared.client {
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
    do {
      Clerk.shared.environment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData)
    } catch {
      ClerkLogger.logError(error, message: "Failed to decode Environment from iOS app")
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

    Task { @MainActor in
      if activationState == .activated, let applicationContext = session.receivedApplicationContext as? [String: Any] {
        if let deviceToken = applicationContext[Self.deviceTokenKey] as? String {
          self.storeDeviceToken(deviceToken)
        }
        if let clientData = applicationContext[Self.clientKey] as? Data {
          self.processSyncedClient(clientData)
        }
        if let environmentData = applicationContext[Self.environmentKey] as? Data {
          self.processSyncedEnvironment(environmentData)
        }
      }
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      if let deviceToken = applicationContext[Self.deviceTokenKey] as? String {
        self.storeDeviceToken(deviceToken)
      }
      if let clientData = applicationContext[Self.clientKey] as? Data {
        self.processSyncedClient(clientData)
      }
      if let environmentData = applicationContext[Self.environmentKey] as? Data {
        self.processSyncedEnvironment(environmentData)
      }
    }
  }
}

#endif
