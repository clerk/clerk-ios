//
//  ClerkIdentitySnapshot.swift
//  Clerk
//

import Foundation

enum ClerkIdentityState {
  case present
  case cleared
}

enum ClerkIdentitySnapshotError: Error, Equatable {
  case invalidPresentState
  case invalidClearedState
  case invalidServerDate
}

/// A complete local Clerk authentication identity.
///
/// The device token, Client, and ordering date always move through the SDK as
/// one value so identity producers cannot persist or expose mismatched halves.
struct ClerkIdentitySnapshot: Equatable {
  let state: ClerkIdentityState
  let deviceToken: String?
  let client: Client?
  let serverDate: Date?

  func validated() throws -> Self {
    let hasToken = deviceToken.nilIfEmpty != nil
    switch state {
    case .present:
      guard hasToken, client != nil else {
        throw ClerkIdentitySnapshotError.invalidPresentState
      }
    case .cleared:
      guard client == nil, deviceToken == nil || hasToken else {
        throw ClerkIdentitySnapshotError.invalidClearedState
      }
    }
    if let serverDate,
       !serverDate.timeIntervalSinceReferenceDate.isFinite
    {
      throw ClerkIdentitySnapshotError.invalidServerDate
    }
    return self
  }
}

extension ClerkIdentitySnapshot {
  static let signedOut = ClerkIdentitySnapshot(state: .cleared, deviceToken: nil, client: nil, serverDate: nil)
}

struct ClerkIdentityRequestSnapshot {
  let deviceToken: String?
  let clientID: String?
  let activeSessionID: String?
  let clientResponseGeneration: ClientResponseGeneration
  let authFlowRegistrationId: UUID?
}
