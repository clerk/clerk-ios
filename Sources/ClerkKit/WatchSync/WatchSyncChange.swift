//
//  WatchSyncChange.swift
//  Clerk
//

import Foundation

/// A sign-in or sign-out on the phone or the watch: the device token and its Client while signed
/// in, or `nil` once signed out, and when that happened. The latest change wins on both devices.
struct WatchSyncChange: Codable, Equatable {
  private enum Key {
    static let deviceToken = "clerkWatchSyncDeviceToken"
    static let clientId = "clerkWatchSyncClientId"
    static let changedAt = "clerkWatchSyncChangedAt"
  }

  let deviceToken: String?
  let clientId: String?
  let changedAt: Date

  init(deviceToken: String?, clientId: String? = nil, changedAt: Date) {
    self.deviceToken = deviceToken
    self.clientId = clientId
    self.changedAt = changedAt
  }

  init?(applicationContext context: [String: Any]) {
    guard let changedAt = context[Key.changedAt] as? Double, changedAt.isFinite else { return nil }
    deviceToken = (context[Key.deviceToken] as? String).nilIfEmpty
    clientId = (context[Key.clientId] as? String).nilIfEmpty
    self.changedAt = Date(timeIntervalSince1970: changedAt)
  }

  var applicationContext: [String: Any] {
    var context: [String: Any] = [Key.changedAt: changedAt.timeIntervalSince1970]
    context[Key.deviceToken] = deviceToken
    context[Key.clientId] = clientId
    return context
  }
}
