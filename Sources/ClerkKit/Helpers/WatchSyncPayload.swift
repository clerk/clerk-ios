//
//  WatchSyncPayload.swift
//  Clerk
//

import Foundation

package enum WatchSyncSource {
  case phone
  case watch

  var incomingDeviceIsAuthoritative: Bool {
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
  private static let clientServerFetchDateKey = "clerkClientServerFetchDate"
  private static let environmentKey = "clerkEnvironment"

  let deviceToken: String?
  let client: Client?
  let clientServerFetchDate: Date?
  let environment: Clerk.Environment?

  init(
    deviceToken: String?,
    client: Client?,
    clientServerFetchDate: Date?,
    environment: Clerk.Environment?
  ) {
    self.deviceToken = deviceToken
    self.client = client
    self.clientServerFetchDate = clientServerFetchDate
    self.environment = environment
  }

  init?(applicationContext: [String: Any]) {
    let deviceToken = applicationContext[Self.deviceTokenKey] as? String
    let clientData = applicationContext[Self.clientKey] as? Data
    let environmentData = applicationContext[Self.environmentKey] as? Data
    let clientServerFetchDate = (applicationContext[Self.clientServerFetchDateKey] as? Double).map(Date.init(timeIntervalSince1970:))

    guard deviceToken != nil || clientData != nil || environmentData != nil else {
      return nil
    }

    self.deviceToken = deviceToken
    self.clientServerFetchDate = clientServerFetchDate
    if let clientData, !clientData.isEmpty {
      guard let decoded = try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData) else {
        ClerkLogger.warning("Failed to decode Client from watch sync payload. Dropping payload.")
        return nil
      }
      client = decoded
    } else {
      client = nil
    }
    if let environmentData {
      if let decoded = try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData) {
        environment = decoded
      } else {
        ClerkLogger.warning("Failed to decode Environment from watch sync payload. Skipping environment field.")
        environment = nil
      }
    } else {
      environment = nil
    }
  }

  @MainActor
  init(clerk: Clerk, keychain: any KeychainStorage) {
    deviceToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    client = clerk.client
    clientServerFetchDate = clerk.lastClientServerFetchDate
    environment = clerk.environment
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
    }

    if let clientServerFetchDate {
      applicationContext[Self.clientServerFetchDateKey] = clientServerFetchDate.timeIntervalSince1970
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

    clerk.applyWatchSyncedClient(
      client,
      incomingServerFetchDate: clientServerFetchDate,
      incomingIsAuthoritative: source.incomingDeviceIsAuthoritative
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

    if !hasSyncedBefore, currentToken != nil, !source.incomingDeviceIsAuthoritative {
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
