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
  /// How many clears this state has seen, merged by maximum across both devices. A state from
  /// before a clear has a lower generation than any state after it, whatever the device and
  /// server clocks say. Payloads from earlier SDKs carry none and count as generation 0, so
  /// they can never undo a clear.
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

  /// Whether `self`, received from `source`, should replace `local`.
  func supersedes(_ local: WatchSyncState, from source: WatchSyncSource) -> Bool {
    // A state from a newer clear generation replaces anything older; only the phone can clear the other device.
    if clearGeneration != local.clearGeneration {
      return clearGeneration > local.clearGeneration && (!isCleared || source == .phone)
    }

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
    static let clearGeneration = "clerkWatchSyncClearGeneration"
    static let legacyDeviceTokenState = "watchSyncDeviceTokenState"
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
    // Payloads from earlier SDKs describe a state when they include a token or an explicit clear.
    let isLegacyClear = context[Key.legacyDeviceTokenState] as? String == "cleared"

    // A complete state needs a decodable client paired with its token.
    if (clientData != nil && client == nil)
      || (client != nil && deviceToken == nil)
      || (!isCurrentSchema && deviceToken == nil && !isLegacyClear)
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
    }
    context[Key.environment] = environment.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
    return context
  }

  private static func date(_ value: Any?) -> Date? {
    guard let interval = value as? Double, interval.isFinite else { return nil }
    return Date(timeIntervalSince1970: interval)
  }
}
