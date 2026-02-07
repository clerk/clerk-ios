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
  /// The associated ``SessionTransition`` describes what kind of change occurred,
  /// letting consumers pattern-match directly instead of tracking previous state.
  case sessionChanged(SessionTransition)
  /// A session token was refreshed.
  case tokenRefreshed(token: String)
}
