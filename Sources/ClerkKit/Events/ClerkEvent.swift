//
//  ClerkEvent.swift
//  Clerk
//

import Foundation

/// An enumeration of general Clerk events.
///
/// `ClerkEvent` represents general events that occur during Clerk operations,
/// such as receiving data from the API.
enum ClerkEvent {
  /// The device token was received from the API.
  case deviceTokenReceived(token: String)
  /// The client was received from the API.
  ///
  /// `requestSequence` is an optional monotonic ordering token that can be
  /// used to reject stale snapshots.
  case clientReceived(client: Client, requestSequence: UInt64?)
  /// The environment was received from the API.
  case environmentReceived(environment: Clerk.Environment)
}
