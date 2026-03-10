//
//  WatchSyncPayload.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package enum WatchSyncSource {
  case phone
  case watch

  var incomingClientIsAuthoritative: Bool {
    self == .phone
  }

  var incomingDeviceTokenWinsFirstSync: Bool {
    self == .phone
  }

  var sourceDescription: String {
    switch self {
    case .phone:
      "iOS app"
    case .watch:
      "watch app"
    }
  }
}

package struct WatchSyncPayload {
  private static let deviceTokenKey = "clerkDeviceToken"
  private static let clientKey = "clerkClient"
  private static let clientSyncAnchorKey = "clerkClientSyncAnchor"
  private static let environmentKey = "clerkEnvironment"

  let deviceToken: String?
  let client: Client?
  let environment: Clerk.Environment?
  let clientSyncAnchor: Date?

  init(
    deviceToken: String?,
    client: Client?,
    environment: Clerk.Environment?,
    clientSyncAnchor: Date?
  ) {
    self.deviceToken = deviceToken
    self.client = client
    self.environment = environment
    self.clientSyncAnchor = clientSyncAnchor
  }

  init?(applicationContext: [String: Any]) {
    let deviceToken = applicationContext[Self.deviceTokenKey] as? String
    let clientData = applicationContext[Self.clientKey] as? Data
    let environmentData = applicationContext[Self.environmentKey] as? Data
    let clientSyncAnchor = (applicationContext[Self.clientSyncAnchorKey] as? Double).map(Date.init(timeIntervalSince1970:))

    guard deviceToken != nil || clientData != nil || environmentData != nil || clientSyncAnchor != nil else {
      return nil
    }

    self.deviceToken = deviceToken
    if let clientData {
      if clientData.isEmpty {
        client = nil
      } else {
        guard let decoded = try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData) else {
          ClerkLogger.warning("Failed to decode Client from watch sync payload. Dropping payload.")
          return nil
        }
        client = decoded
      }
    } else {
      client = nil
    }
    if let environmentData {
      guard let decoded = try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData) else {
        ClerkLogger.warning("Failed to decode Environment from watch sync payload. Dropping payload.")
        return nil
      }
      environment = decoded
    } else {
      environment = nil
    }
    self.clientSyncAnchor = clientSyncAnchor
  }

  @MainActor
  init(clerk: Clerk, keychain: any KeychainStorage) {
    deviceToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    client = clerk.client
    environment = clerk.environment
    clientSyncAnchor = clerk.watchSyncClientAnchor
  }

  var applicationContext: [String: Any] {
    var applicationContext: [String: Any] = [:]

    if let deviceToken {
      applicationContext[Self.deviceTokenKey] = deviceToken
    }

    if let client {
      do {
        applicationContext[Self.clientKey] = try JSONEncoder.clerkEncoder.encode(client)
      } catch {
        ClerkLogger.logError(error, message: "Failed to serialize Client for watch sync")
      }
    } else {
      applicationContext[Self.clientKey] = Data()
    }

    if let clientSyncAnchor {
      applicationContext[Self.clientSyncAnchorKey] = clientSyncAnchor.timeIntervalSince1970
    }

    if let environment {
      do {
        applicationContext[Self.environmentKey] = try JSONEncoder.clerkEncoder.encode(environment)
      } catch {
        ClerkLogger.logError(error, message: "Failed to serialize Environment for watch sync")
      }
    }

    return applicationContext
  }

  @MainActor
  func apply(from source: WatchSyncSource, to clerk: Clerk, keychain: any KeychainStorage) {
    if let deviceToken {
      applyDeviceToken(
        deviceToken,
        from: source,
        keychain: keychain
      )
    }

    if let environment {
      clerk.environment = environment
    }

    guard clientSyncAnchor != nil || client != nil else {
      return
    }

    clerk.applyWatchSyncedClient(
      client,
      syncedAt: clientSyncAnchor,
      incomingIsAuthoritative: source.incomingClientIsAuthoritative
    )
  }

  @MainActor
  private func applyDeviceToken(
    _ deviceToken: String,
    from source: WatchSyncSource,
    keychain: any KeychainStorage
  ) {
    let hasSyncedBefore = (try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue)) == "true"
    let currentToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    if !hasSyncedBefore, currentToken != nil, !source.incomingDeviceTokenWinsFirstSync {
      do {
        try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue)
      } catch {
        ClerkLogger.logError(error, message: "Failed to store deviceToken sync state")
      }
      return
    }

    do {
      try keychain.set(deviceToken, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
      if !hasSyncedBefore {
        try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue)
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to store deviceToken from \(source.sourceDescription)")
    }
  }
}
