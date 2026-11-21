//
//  ServerClock.swift
//  Clerk
//

import Foundation

struct ServerClock {
  private(set) var deviceLag: TimeInterval = 0
  private var lastServerDate: (date: Date, receivedAt: ContinuousClock.Instant)?

  var now: Date {
    Date.now.addingTimeInterval(deviceLag)
  }

  /// An HTTP `Date` has one-second resolution and is stamped before the response travels (RFC 9110 §6.6.1),
  /// so it reads behind the server by an unknown amount. Only a date ahead of the device can prove the device lags.
  mutating func record(
    serverDate: Date,
    receivedAt: Date,
    receivedAtInstant: ContinuousClock.Instant = .now
  ) {
    deviceLag = max(0, receivedAt.distance(to: serverDate))
    lastServerDate = (serverDate, receivedAtInstant)
  }

  /// The time a DPoP proof names in `iat`. FAPI rejects an `iat` more than 30 seconds ahead of its clock, so a
  /// proof counts forward from the last server `Date` on a clock the device's wall clock cannot move.
  func proofDate(at instant: ContinuousClock.Instant = .now) -> Date {
    guard let lastServerDate else { return .now }
    let elapsed = lastServerDate.receivedAt.duration(to: instant).components
    return lastServerDate.date.addingTimeInterval(
      TimeInterval(elapsed.seconds) + TimeInterval(elapsed.attoseconds) / 1e18
    )
  }
}
