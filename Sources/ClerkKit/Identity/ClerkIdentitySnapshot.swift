//
//  ClerkIdentitySnapshot.swift
//  Clerk
//

import Foundation

enum ClerkIdentityState: String, Codable {
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
struct ClerkIdentitySnapshot: Codable, Equatable {
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
  /// Keeps the device token when the Client cannot be decoded, for example after a newer
  /// SDK in another app wrote a Client shape this version does not understand. Losing the
  /// token would sign the user out; the next refresh restores the Client.
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
    let client: Client?
    do {
      client = try container.decodeIfPresent(Client.self, forKey: .client)
    } catch {
      ClerkLogger.logError(error, message: "Failed to decode the persisted Clerk client; keeping the device token")
      client = nil
    }
    try self.init(
      state: client == nil ? .cleared : container.decode(ClerkIdentityState.self, forKey: .state),
      deviceToken: deviceToken,
      client: client,
      serverDate: container.decodeIfPresent(Date.self, forKey: .serverDate)
    )
  }

  static let signedOut = ClerkIdentitySnapshot(state: .cleared, deviceToken: nil, client: nil, serverDate: nil)
}

struct ClerkIdentityRequestSnapshot {
  let deviceToken: String?
  let clientID: String?
  let clientResponseGeneration: ClientResponseGeneration
  let authFlowRegistrationId: UUID?
}
