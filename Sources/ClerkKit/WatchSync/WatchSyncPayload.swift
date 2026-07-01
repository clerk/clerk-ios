//
//  WatchSyncPayload.swift
//  Clerk
//

import Foundation

package struct WatchSyncVersion: Hashable, Comparable {
  static let initial = WatchSyncVersion(rawValue: 0)

  let rawValue: Int

  func next() -> WatchSyncVersion {
    WatchSyncVersion(rawValue: rawValue + 1)
  }

  package static func < (lhs: WatchSyncVersion, rhs: WatchSyncVersion) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

package enum WatchSyncDeviceTokenUpdate: Equatable {
  case notIncluded
  case tokenSet(token: String, version: WatchSyncVersion?)
  case tokenCleared(version: WatchSyncVersion?)

  var version: WatchSyncVersion? {
    switch self {
    case .notIncluded:
      nil
    case let .tokenSet(_, version), let .tokenCleared(version):
      version
    }
  }
}

package enum WatchSyncClientUpdate: Equatable {
  case notIncluded
  case snapshot(client: Client, serverFetchDate: Date?, version: WatchSyncVersion?)
  case cleared(serverFetchDate: Date?, version: WatchSyncVersion?)

  var version: WatchSyncVersion? {
    switch self {
    case .notIncluded:
      nil
    case let .snapshot(_, _, version), let .cleared(_, version):
      version
    }
  }

  var client: Client? {
    switch self {
    case .notIncluded, .cleared:
      nil
    case let .snapshot(client, _, _):
      client
    }
  }

  var serverFetchDate: Date? {
    switch self {
    case .notIncluded:
      nil
    case let .snapshot(_, serverFetchDate, _), let .cleared(serverFetchDate, _):
      serverFetchDate
    }
  }
}

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
  private static let deviceTokenStateKey = "watchSyncDeviceTokenState"
  private static let deviceTokenVersionKey = "watchSyncDeviceTokenVersion"
  private static let clientKey = "clerkClient"
  private static let authStateKey = "watchSyncAuthState"
  private static let authVersionKey = "watchSyncAuthVersion"
  private static let clientServerFetchDateKey = "clerkClientServerFetchDate"
  private static let environmentKey = "clerkEnvironment"

  let deviceTokenUpdate: WatchSyncDeviceTokenUpdate
  let clientUpdate: WatchSyncClientUpdate
  let environment: Clerk.Environment?

  var deviceToken: String? {
    switch deviceTokenUpdate {
    case .notIncluded, .tokenCleared:
      nil
    case let .tokenSet(token, _):
      token
    }
  }

  var client: Client? {
    clientUpdate.client
  }

  var clientServerFetchDate: Date? {
    clientUpdate.serverFetchDate
  }

  init(
    deviceToken: String?,
    client: Client?,
    clientServerFetchDate: Date?,
    environment: Clerk.Environment?
  ) {
    deviceTokenUpdate = deviceToken.map { .tokenSet(token: $0, version: nil) } ?? .notIncluded
    clientUpdate = client.map { .snapshot(client: $0, serverFetchDate: clientServerFetchDate, version: nil) } ?? .notIncluded
    self.environment = environment
  }

  init(
    deviceTokenUpdate: WatchSyncDeviceTokenUpdate,
    clientUpdate: WatchSyncClientUpdate,
    environment: Clerk.Environment?
  ) {
    self.deviceTokenUpdate = deviceTokenUpdate
    self.clientUpdate = clientUpdate
    self.environment = environment
  }

  init?(applicationContext: [String: Any]) {
    let deviceTokenUpdate = Self.decodeDeviceTokenUpdate(from: applicationContext)
    let clientData = applicationContext[Self.clientKey] as? Data
    let environmentData = applicationContext[Self.environmentKey] as? Data
    let clientServerFetchDate = (applicationContext[Self.clientServerFetchDateKey] as? Double).map(Date.init(timeIntervalSince1970:))
    let clientUpdate = Self.decodeClientUpdate(
      from: applicationContext,
      clientData: clientData,
      clientServerFetchDate: clientServerFetchDate
    )

    guard deviceTokenUpdate != .notIncluded || clientUpdate != .notIncluded || environmentData != nil else {
      return nil
    }

    self.deviceTokenUpdate = deviceTokenUpdate
    self.clientUpdate = clientUpdate
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
  init(clerk: Clerk, keychain: any KeychainStorage, authGeneration: WatchSyncVersion) {
    deviceTokenUpdate = Self.deviceTokenUpdate(keychain: keychain)
    let persistedAuthState = try? keychain.string(forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)
    if let client = clerk.client {
      clientUpdate = .snapshot(client: client, serverFetchDate: clerk.lastClientServerFetchDate, version: authGeneration)
    } else if clerk.lastClientServerFetchDate != nil || persistedAuthState == "cleared" {
      clientUpdate = .cleared(serverFetchDate: clerk.lastClientServerFetchDate, version: authGeneration)
    } else {
      clientUpdate = .notIncluded
    }
    environment = clerk.environment
  }

  var applicationContext: [String: Any] {
    var applicationContext: [String: Any] = [:]

    switch deviceTokenUpdate {
    case .notIncluded:
      break
    case let .tokenSet(deviceToken, version):
      applicationContext[Self.deviceTokenKey] = deviceToken
      applicationContext[Self.deviceTokenStateKey] = "set"
      if let version {
        applicationContext[Self.deviceTokenVersionKey] = version.rawValue
      }
    case let .tokenCleared(version):
      applicationContext[Self.deviceTokenStateKey] = "cleared"
      if let version {
        applicationContext[Self.deviceTokenVersionKey] = version.rawValue
      }
    }

    switch clientUpdate {
    case .notIncluded:
      break
    case let .snapshot(client, clientServerFetchDate, version):
      applicationContext[Self.authStateKey] = "set"
      do {
        applicationContext[Self.clientKey] = try JSONEncoder.clerkEncoder.encode(client)
      } catch {
        ClerkLogger.logError(error, message: "Failed to serialize Client for watch sync")
      }
      if let clientServerFetchDate {
        applicationContext[Self.clientServerFetchDateKey] = clientServerFetchDate.timeIntervalSince1970
      }
      if let version {
        applicationContext[Self.authVersionKey] = version.rawValue
      }
    case let .cleared(clientServerFetchDate, version):
      applicationContext[Self.authStateKey] = "cleared"
      if let clientServerFetchDate {
        applicationContext[Self.clientServerFetchDateKey] = clientServerFetchDate.timeIntervalSince1970
      }
      if let version {
        applicationContext[Self.authVersionKey] = version.rawValue
      }
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

  private static func decodeDeviceTokenUpdate(from applicationContext: [String: Any]) -> WatchSyncDeviceTokenUpdate {
    let state = applicationContext[deviceTokenStateKey] as? String
    let version = decodeVersion(applicationContext[deviceTokenVersionKey])
    let deviceToken = applicationContext[deviceTokenKey] as? String

    switch state {
    case "set":
      guard let deviceToken else { return .notIncluded }
      return .tokenSet(token: deviceToken, version: version)
    case "cleared":
      return .tokenCleared(version: version)
    default:
      return deviceToken.map { .tokenSet(token: $0, version: nil) } ?? .notIncluded
    }
  }

  private static func decodeClientUpdate(
    from applicationContext: [String: Any],
    clientData: Data?,
    clientServerFetchDate: Date?
  ) -> WatchSyncClientUpdate {
    let state = applicationContext[authStateKey] as? String
    let version = decodeVersion(applicationContext[authVersionKey])

    switch state {
    case "set":
      guard let clientData, !clientData.isEmpty else { return .notIncluded }
      guard let decoded = try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData) else {
        ClerkLogger.warning("Failed to decode Client from watch sync payload. Dropping payload.")
        return .notIncluded
      }
      return .snapshot(client: decoded, serverFetchDate: clientServerFetchDate, version: version)
    case "cleared":
      return .cleared(serverFetchDate: clientServerFetchDate, version: version)
    default:
      guard let clientData, !clientData.isEmpty else {
        if let clientServerFetchDate {
          return .cleared(serverFetchDate: clientServerFetchDate, version: nil)
        }
        return .notIncluded
      }
      guard let decoded = try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData) else {
        ClerkLogger.warning("Failed to decode Client from watch sync payload. Dropping payload.")
        return .notIncluded
      }
      return .snapshot(client: decoded, serverFetchDate: clientServerFetchDate, version: nil)
    }
  }

  private static func decodeVersion(_ value: Any?) -> WatchSyncVersion? {
    if let value = value as? Int {
      return WatchSyncVersion(rawValue: value)
    }
    if let value = value as? Double {
      return WatchSyncVersion(rawValue: Int(value))
    }
    if let value = value as? String, let intValue = Int(value) {
      return WatchSyncVersion(rawValue: intValue)
    }
    return nil
  }

  private static func deviceTokenUpdate(keychain: any KeychainStorage) -> WatchSyncDeviceTokenUpdate {
    let version = readDeviceTokenVersion(keychain: keychain)
    if let deviceToken = try? keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) {
      return .tokenSet(token: deviceToken, version: version)
    }

    let state = try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)
    if state == "cleared" {
      return .tokenCleared(version: version)
    }

    return .notIncluded
  }

  private static func readDeviceTokenVersion(keychain: any KeychainStorage) -> WatchSyncVersion {
    guard let versionString = try? keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue),
          let version = Int(versionString)
    else {
      return .initial
    }

    return WatchSyncVersion(rawValue: version)
  }
}
