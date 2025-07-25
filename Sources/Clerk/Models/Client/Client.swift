//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import FactoryKit
import Foundation

/// The Client object keeps track of the authenticated sessions in the current device. The device can be a browser, a native application or any other medium that is usually the requesting part in a request/response architecture.
///
/// The Client object also holds information about any sign in or sign up attempts that might be in progress, tracking the sign in or sign up progress.
public struct Client: Codable, Sendable, Equatable {

  /// Unique identifier for this client.
  public let id: String

  /// The current sign in attempt, or nil if there is none.
  public let signIn: SignIn?

  /// The current sign up attempt, or nil if there is none.
  public let signUp: SignUp?

  /// A list of sessions that have been created on this client.
  public let sessions: [Session]

  /// A list of active sessions on this client.
  public var activeSessions: [Session] {
    sessions.filter { $0.status == .active }
  }

  /// The ID of the last active Session on this client.
  public let lastActiveSessionId: String?

  /// Timestamp of last update for the client.
  public let updatedAt: Date

  public init(
    id: String,
    signIn: SignIn? = nil,
    signUp: SignUp? = nil,
    sessions: [Session],
    lastActiveSessionId: String? = nil,
    updatedAt: Date
  ) {
    self.id = id
    self.signIn = signIn
    self.signUp = signUp
    self.sessions = sessions
    self.lastActiveSessionId = lastActiveSessionId
    self.updatedAt = updatedAt
  }
}

extension Client {

  /// Retrieves the current client.
  @discardableResult @MainActor
  public static func get() async throws -> Client? {
    let request = ClerkFAPI.v1.client.get
    return try await Container.shared.apiClient().send(request).value.response
  }

}

extension Client {

  static var mock: Client {
    return Client(
      id: "1",
      signIn: .mock,
      signUp: .mock,
      sessions: [.mock, .mock2],
      lastActiveSessionId: "1",
      updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }
  
  static var mockSignedOut: Client {
    return Client(
      id: "2",
      signIn: .mock,
      signUp: .mock,
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
    )
  }

}
