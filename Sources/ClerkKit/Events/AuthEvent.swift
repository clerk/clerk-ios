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
  /// A Clerk callback recovered an incomplete sign-in flow that can continue.
  case signInNeedsContinuation(signIn: SignIn)
  /// The current sign up was completed.
  case signUpCompleted(signUp: SignUp)
  /// A Clerk callback recovered an incomplete sign-up flow that can continue.
  case signUpNeedsContinuation(signUp: SignUp)
  /// A session was signed out.
  case signedOut(session: Session)
  /// The current account was deleted.
  case accountDeleted
  /// The current session changed.
  ///
  /// This event is emitted whenever the current session changes, including:
  /// - When a user signs in (nil → session)
  /// - When a user signs out (session → nil)
  /// - When the current session changes (session → different session)
  /// - When the same session is updated (e.g., status, updatedAt changed)
  case sessionChanged(oldValue: Session?, newValue: Session?)
  /// A session token was refreshed.
  case tokenRefreshed(token: String)
}
