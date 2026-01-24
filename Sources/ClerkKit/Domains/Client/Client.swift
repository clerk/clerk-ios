//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/// The Client object keeps track of the authenticated sessions in the current device. The device can be a browser, a native application or any other medium that is usually the requesting part in a request/response architecture.
///
/// The Client object also holds information about any sign in or sign up attempts that might be in progress, tracking the sign in or sign up progress.
public struct Client: Codable, Sendable, Equatable {
  /// Unique identifier for this client.
  public var id: String

  /// The current sign in attempt, or nil if there is none.
  public var signIn: SignIn?

  /// The current sign up attempt, or nil if there is none.
  public var signUp: SignUp?

  /// A list of sessions that have been created on this client.
  public var sessions: [Session]

  /// A list of active sessions on this client.
  public var activeSessions: [Session] {
    sessions.filter { $0.status == .active }
  }

  /// The ID of the last active Session on this client.
  public var lastActiveSessionId: String?

  /// The authentication strategy used for the last sign-in attempt, if available.
  public var lastAuthenticationStrategy: FactorStrategy?

  /// Timestamp of last update for the client.
  public var updatedAt: Date

  public init(
    id: String,
    signIn: SignIn? = nil,
    signUp: SignUp? = nil,
    sessions: [Session],
    lastActiveSessionId: String? = nil,
    lastAuthenticationStrategy: FactorStrategy? = nil,
    updatedAt: Date
  ) {
    self.id = id
    self.signIn = signIn
    self.signUp = signUp
    self.sessions = sessions
    self.lastActiveSessionId = lastActiveSessionId
    self.lastAuthenticationStrategy = lastAuthenticationStrategy
    self.updatedAt = updatedAt
  }
}
