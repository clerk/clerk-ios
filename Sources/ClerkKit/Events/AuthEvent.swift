//
//  AuthEvent.swift
//  Clerk
//

import Foundation

/// An enumeration of authentication-related events.
///
/// `AuthEvent` represents specific events that occur during authentication processes,
/// such as signing in or signing up.
public enum AuthEvent: Sendable {
  /// The current sign in was completed.
  case signInCompleted(signIn: SignIn)
  /// The current sign up was completed.
  case signUpCompleted(signUp: SignUp)
  /// A session was signed out.
  case signedOut(session: Session)
  /// The current session changed.
  ///
  /// This event is emitted whenever the current session changes, including:
  /// - When a user signs in (`.activated`)
  /// - When a user signs out (`.unauthenticated`)
  /// - When the current session changes to a different session (`.activated` or `.pending`)
  /// - When the same session is updated, e.g. status or metadata changed (`.updated`)
  case sessionChanged(SessionTransition)
  /// A session token was refreshed.
  case tokenRefreshed(token: String)
}
