//
//  WatchSyncChange.swift
//  Clerk
//

import Foundation

/// A sign-in or sign-out on the phone or the watch: the device token while signed in, or `nil`
/// once signed out, and when that happened. The latest change wins on both devices.
struct WatchSyncChange: Codable, Equatable {
  private enum Key {
    static let deviceToken = "clerkWatchSyncDeviceToken"
    static let changedAt = "clerkWatchSyncChangedAt"
  }

  let deviceToken: String?
  let changedAt: Date

  init(deviceToken: String?, changedAt: Date) {
    self.deviceToken = deviceToken
    self.changedAt = changedAt
  }

  init?(applicationContext context: [String: Any]) {
    guard let changedAt = context[Key.changedAt] as? Double, changedAt.isFinite else { return nil }
    deviceToken = (context[Key.deviceToken] as? String).nilIfEmpty
    self.changedAt = Date(timeIntervalSince1970: changedAt)
  }

  var applicationContext: [String: Any] {
    var context: [String: Any] = [Key.changedAt: changedAt.timeIntervalSince1970]
    context[Key.deviceToken] = deviceToken
    return context
  }
}
