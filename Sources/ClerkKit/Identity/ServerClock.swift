//
//  ServerClock.swift
//  Clerk
//

import Foundation

struct ServerClock {
  private(set) var deviceLag: TimeInterval = 0

  var now: Date {
    Date.now.addingTimeInterval(deviceLag)
  }

  /// An HTTP `Date` has one-second resolution and is stamped before the response travels (RFC 9110 §6.6.1),
  /// so it reads behind the server by an unknown amount. Only a date ahead of the device can prove the device lags.
  mutating func record(serverDate: Date, receivedAt: Date) {
    deviceLag = max(0, receivedAt.distance(to: serverDate))
  }
}
