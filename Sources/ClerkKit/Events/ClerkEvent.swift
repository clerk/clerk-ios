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
  case clientReceived(client: Client)
  /// The environment was received from the API.
  case environmentReceived(environment: Clerk.Environment)
}
