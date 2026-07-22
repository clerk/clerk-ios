//
//  WatchSyncPayload.swift
//  Clerk
//

import Foundation

package struct WatchSyncVersion: Hashable, Comparable {
  package enum Error: Swift.Error, Equatable {
    case exhausted
  }

  static let initial = WatchSyncVersion(rawValue: 0)

  let rawValue: Int

  func next() throws -> WatchSyncVersion {
    guard rawValue < Int.max else { throw Error.exhausted }
    return WatchSyncVersion(rawValue: rawValue + 1)
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

package enum WatchSyncSource: String, Codable {
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
    let hasDeviceTokenState = applicationContext.keys.contains(Self.deviceTokenStateKey)
    let hasDeviceTokenVersion = applicationContext.keys.contains(Self.deviceTokenVersionKey)
    let hasAuthState = applicationContext.keys.contains(Self.authStateKey)
    let hasAuthVersion = applicationContext.keys.contains(Self.authVersionKey)
    guard !hasDeviceTokenVersion || hasDeviceTokenState,
          !hasAuthVersion || hasAuthState
    else {
      return nil
    }
    if hasDeviceTokenState {
      guard Self.decodeMetadataState(applicationContext[Self.deviceTokenStateKey]) != nil else {
        return nil
      }
      if let rawVersion = applicationContext[Self.deviceTokenVersionKey] {
        guard let version = Self.decodeVersion(rawVersion), version >= .initial else {
          return nil
        }
      }
    }
    if hasAuthState {
      guard Self.decodeMetadataState(applicationContext[Self.authStateKey]) != nil else {
        return nil
      }
      if let rawVersion = applicationContext[Self.authVersionKey] {
        guard let version = Self.decodeVersion(rawVersion), version >= .initial else {
          return nil
        }
      }
    }

    let deviceTokenUpdate = Self.decodeDeviceTokenUpdate(from: applicationContext)
    let clientData = applicationContext[Self.clientKey] as? Data
    let environmentData = applicationContext[Self.environmentKey] as? Data
    let clientServerFetchDate: Date?
    if let rawServerFetchDate = applicationContext[Self.clientServerFetchDateKey] as? Double {
      guard rawServerFetchDate.isFinite else { return nil }
      clientServerFetchDate = Date(timeIntervalSince1970: rawServerFetchDate)
    } else {
      clientServerFetchDate = nil
    }
    let clientUpdate = Self.decodeClientUpdate(
      from: applicationContext,
      clientData: clientData,
      clientServerFetchDate: clientServerFetchDate
    )

    guard !hasDeviceTokenState || deviceTokenUpdate != .notIncluded,
          !hasAuthState || clientUpdate != .notIncluded
    else {
      return nil
    }

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
  init(
    clerk: Clerk,
    metadata: WatchSyncMetadataRecord,
    authGeneration: WatchSyncVersion
  ) throws {
    guard !metadata.hasPendingIdentityMetadata else {
      throw ClerkClientError(message: "Cannot publish unresolved Watch identity metadata.")
    }
    deviceTokenUpdate = Self.deviceTokenUpdate(
      deviceToken: clerk.deviceToken,
      metadata: metadata
    )
    let persistedAuthState = metadata.authState
    if let client = clerk.authoritativeClient {
      clientUpdate = .snapshot(client: client, serverFetchDate: clerk.lastClientServerFetchDate, version: authGeneration)
    } else if clerk.lastClientServerFetchDate != nil || persistedAuthState == .cleared {
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
      if let version {
        applicationContext[Self.deviceTokenStateKey] = WatchSyncMetadataState.set.rawValue
        applicationContext[Self.deviceTokenVersionKey] = version.rawValue
      }
    case let .tokenCleared(version):
      if let version {
        applicationContext[Self.deviceTokenStateKey] = WatchSyncMetadataState.cleared.rawValue
        applicationContext[Self.deviceTokenVersionKey] = version.rawValue
      }
    }

    switch clientUpdate {
    case .notIncluded:
      break
    case let .snapshot(client, clientServerFetchDate, version):
      do {
        applicationContext[Self.clientKey] = try JSONEncoder.clerkEncoder.encode(client)
      } catch {
        ClerkLogger.logError(error, message: "Failed to serialize Client for watch sync")
      }
      if let clientServerFetchDate {
        applicationContext[Self.clientServerFetchDateKey] = clientServerFetchDate.timeIntervalSince1970
      }
      if let version {
        applicationContext[Self.authStateKey] = WatchSyncMetadataState.set.rawValue
        applicationContext[Self.authVersionKey] = version.rawValue
      }
    case let .cleared(clientServerFetchDate, version):
      if let clientServerFetchDate {
        applicationContext[Self.clientServerFetchDateKey] = clientServerFetchDate.timeIntervalSince1970
      }
      if let version {
        applicationContext[Self.authStateKey] = WatchSyncMetadataState.cleared.rawValue
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
    let state = decodeMetadataState(applicationContext[deviceTokenStateKey])
    let version = decodeVersion(applicationContext[deviceTokenVersionKey])
    let deviceToken = applicationContext[deviceTokenKey] as? String

    switch state {
    case .set:
      guard let deviceToken else { return .notIncluded }
      return .tokenSet(token: deviceToken, version: version)
    case .cleared:
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
    let state = decodeMetadataState(applicationContext[authStateKey])
    let version = decodeVersion(applicationContext[authVersionKey])

    switch state {
    case .set:
      guard let clientData, !clientData.isEmpty else { return .notIncluded }
      guard let decoded = try? JSONDecoder.clerkDecoder.decode(Client.self, from: clientData) else {
        ClerkLogger.warning("Failed to decode Client from watch sync payload. Dropping payload.")
        return .notIncluded
      }
      return .snapshot(client: decoded, serverFetchDate: clientServerFetchDate, version: version)
    case .cleared:
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
    if let value = value as? Double,
       value.isFinite,
       value.rounded(.towardZero) == value,
       let intValue = Int(exactly: value)
    {
      return WatchSyncVersion(rawValue: intValue)
    }
    if let value = value as? String, let intValue = Int(value) {
      return WatchSyncVersion(rawValue: intValue)
    }
    return nil
  }

  private static func decodeMetadataState(_ value: Any?) -> WatchSyncMetadataState? {
    guard let value = value as? String else { return nil }
    return WatchSyncMetadataState(rawValue: value)
  }

  private static func deviceTokenUpdate(
    deviceToken: String?,
    metadata: WatchSyncMetadataRecord
  ) -> WatchSyncDeviceTokenUpdate {
    let version = WatchSyncVersion(rawValue: metadata.deviceTokenVersion ?? 0)
    if let deviceToken {
      return .tokenSet(token: deviceToken, version: version)
    }

    if metadata.deviceTokenState == .cleared {
      return .tokenCleared(version: version)
    }

    return .notIncluded
  }
}
