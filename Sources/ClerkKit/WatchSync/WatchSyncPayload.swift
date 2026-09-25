//
//  WatchSyncPayload.swift
//  Clerk
//

import Foundation

package enum WatchSyncSource: Equatable {
  case phone
  case watch
}

/// One device's complete Clerk auth state, as exchanged between phone and watch.
///
/// The device token names a server-side Client, so two devices holding the same
/// token share one Client and only need to agree on the newest snapshot of it.
package struct WatchSyncState: Equatable {
  let deviceToken: String?
  let client: Client?
  /// `Date` header of the response that produced `client`.
  let serverDate: Date?
  /// When this device last cleared its local Clerk storage.
  let clearedAt: Date?

  init(deviceToken: String?, client: Client?, serverDate: Date?, clearedAt: Date? = nil) {
    self.deviceToken = deviceToken.nilIfEmpty
    self.client = client
    self.serverDate = serverDate
    self.clearedAt = clearedAt
  }

  var isCleared: Bool {
    deviceToken == nil
  }

  var hasSession: Bool {
    client?.sessions.isEmpty == false
  }

  /// The most recent auth event this state reflects.
  var orderingDate: Date {
    max(serverDate ?? .distantPast, clearedAt ?? .distantPast)
  }

  /// Whether `self`, received from `source`, should replace `local`.
  func supersedes(_ local: WatchSyncState, from source: WatchSyncSource) -> Bool {
    // Same token: both devices share one server-side Client, so the newer snapshot wins.
    if deviceToken == local.deviceToken {
      guard let client else { return false }
      guard let localClient = local.client else { return true }
      guard let serverDate else { return false }
      guard let localDate = local.serverDate else { return true }
      if serverDate != localDate { return serverDate > localDate }
      return client.updatedAt > localClient.updatedAt
    }

    // Different tokens name different Clients.
    if let localClearedAt = local.clearedAt, orderingDate <= localClearedAt {
      return false // Never bring back an identity from before this device's last clear.
    }
    if isCleared { return source == .phone } // Only the phone can clear the other device.
    if local.isCleared { return true } // Seed a device that has no token.
    if hasSession != local.hasSession { return hasSession } // A signed-in Client beats a signed-out one.
    return source == .phone
  }
}

package struct WatchSyncPayload: Equatable {
  private enum Key {
    static let schema = "clerkWatchSyncSchema"
    static let deviceToken = "clerkDeviceToken"
    static let client = "clerkClient"
    static let serverDate = "clerkClientServerFetchDate"
    static let clearedAt = "clerkWatchSyncClearedAt"
    static let environment = "clerkEnvironment"
  }

  private static let schemaVersion = 2

  /// `nil` when the payload carries no usable auth state.
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

    // A complete state needs a decodable client paired with its token. Payloads
    // from older SDKs only describe a state when they include a token.
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
        clearedAt: isCurrentSchema ? Self.date(context[Key.clearedAt]) : nil
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
      context[Key.clearedAt] = state.clearedAt?.timeIntervalSince1970
    }
    context[Key.environment] = environment.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
    return context
  }

  private static func date(_ value: Any?) -> Date? {
    guard let interval = value as? Double, interval.isFinite else { return nil }
    return Date(timeIntervalSince1970: interval)
  }
}
