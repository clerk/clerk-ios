//
//  WatchSyncPayload.swift
//  Clerk
//

import Foundation

package enum WatchSyncSource: Equatable {
  case phone
  case watch
}

package struct WatchSyncState: Equatable {
  let deviceToken: String?
  let client: Client?
  let serverDate: Date?
  let clearGeneration: Int

  init(deviceToken: String?, client: Client?, serverDate: Date?, clearGeneration: Int = 0) {
    self.deviceToken = deviceToken.nilIfEmpty
    self.client = client
    self.serverDate = serverDate
    self.clearGeneration = clearGeneration
  }

  var isCleared: Bool {
    deviceToken == nil
  }

  var hasSession: Bool {
    client?.sessions.isEmpty == false
  }

  func supersedes(_ local: WatchSyncState, from source: WatchSyncSource) -> Bool {
    if clearGeneration != local.clearGeneration {
      return clearGeneration > local.clearGeneration
    }

    if deviceToken == local.deviceToken || (client != nil && client?.id == local.client?.id) {
      guard let client else { return false }
      guard let localClient = local.client else { return true }
      guard let serverDate else { return false }
      guard let localDate = local.serverDate else { return true }
      if serverDate != localDate { return serverDate > localDate }
      if client.updatedAt != localClient.updatedAt { return client.updatedAt > localClient.updatedAt }
      return deviceToken != local.deviceToken && source == .phone
    }

    if isCleared { return false }
    if local.isCleared { return true }
    if hasSession != local.hasSession { return hasSession }
    return source == .phone
  }
}

package struct WatchSyncPayload: Equatable {
  private enum Key {
    static let schema = "clerkWatchSyncSchema"
    static let deviceToken = "clerkDeviceToken"
    static let client = "clerkClient"
    static let serverDate = "clerkClientServerFetchDate"
    static let clearGeneration = "clerkWatchSyncClearGeneration"
    static let environment = "clerkEnvironment"
  }

  /// Keys an SDK 1.5 peer reads. Once synced, SDK 1.5 accepts only versioned updates, so a payload
  /// without them could not sign out a paired device that has not updated yet. Remove after one release.
  private enum LegacyKey {
    static let deviceTokenState = "watchSyncDeviceTokenState"
    static let deviceTokenVersion = "watchSyncDeviceTokenVersion"
    static let authState = "watchSyncAuthState"
    static let authVersion = "watchSyncAuthVersion"
  }

  private static let schemaVersion = 2

  let state: WatchSyncState?
  let environment: Clerk.Environment?

  init(state: WatchSyncState?, environment: Clerk.Environment?) {
    self.state = state
    self.environment = environment
  }

  init?(applicationContext context: [String: Any]) {
    environment = (context[Key.environment] as? Data).flatMap {
      try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: $0)
    }

    let deviceToken = (context[Key.deviceToken] as? String).nilIfEmpty
    let clientData = context[Key.client] as? Data
    let client = clientData.flatMap {
      try? JSONDecoder.clerkDecoder.decode(Client.self, from: $0)
    }
    let isCurrentSchema = context[Key.schema] as? Int == Self.schemaVersion

    if (clientData != nil && client == nil)
      || (client != nil && deviceToken == nil)
      || (!isCurrentSchema && deviceToken == nil)
    {
      state = nil
    } else {
      state = WatchSyncState(
        deviceToken: deviceToken,
        client: client,
        serverDate: Self.date(context[Key.serverDate]),
        clearGeneration: isCurrentSchema ? (context[Key.clearGeneration] as? Int ?? 0) : 0
      )
    }

    guard state != nil || environment != nil else { return nil }
  }

  var applicationContext: [String: Any] {
    var context: [String: Any] = [:]
    if let state {
      context[Key.schema] = Self.schemaVersion
      context[Key.deviceToken] = state.deviceToken
      context[Key.client] = state.client.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
      context[Key.serverDate] = state.serverDate?.timeIntervalSince1970
      context[Key.clearGeneration] = state.clearGeneration
      Self.addLegacyKeys(for: state, to: &context)
    }
    context[Key.environment] = environment.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
    return context
  }

  private static func addLegacyKeys(for state: WatchSyncState, to context: inout [String: Any]) {
    let version = Int(Date().timeIntervalSince1970 * 1000)
    if state.deviceToken != nil {
      context[LegacyKey.deviceTokenState] = "set"
      context[LegacyKey.deviceTokenVersion] = version
      if state.client != nil {
        context[LegacyKey.authState] = "set"
        context[LegacyKey.authVersion] = version
      }
    } else if state.clearGeneration > 0 {
      context[LegacyKey.deviceTokenState] = "cleared"
      context[LegacyKey.deviceTokenVersion] = version
      context[LegacyKey.authState] = "cleared"
      context[LegacyKey.authVersion] = version
    }
  }

  private static func date(_ value: Any?) -> Date? {
    guard let interval = value as? Double, interval.isFinite else { return nil }
    return Date(timeIntervalSince1970: interval)
  }
}
