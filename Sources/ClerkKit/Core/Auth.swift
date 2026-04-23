//
//  Auth.swift
//  Clerk
//

import Foundation

/// The main entry point for all authentication operations in the Clerk SDK.
///
/// Access this via `clerk.auth` to perform sign in, sign up, and session management operations.
/// This is a lightweight facade that namespaces auth-related methods - it holds no state itself.
@MainActor
public struct Auth {
  let clerk: Clerk
  let signInService: SignInServiceProtocol
  let signUpService: SignUpServiceProtocol
  let sessionService: SessionServiceProtocol
  let sessionTokenFetcher: SessionTokenFetcher
  let eventEmitter: EventEmitter<AuthEvent>

  /// The current sign-in attempt, if any.
  ///
  /// This mirrors the in-progress `SignIn` stored on the current client.
  /// Useful for continuing identifier-first flows or multi-step verifications.
  ///
  /// ```swift
  /// if let signIn = clerk.auth.currentSignIn {
  ///   // Continue the flow with the existing SignIn instance
  ///   _ = try await signIn.sendEmailCode()
  /// }
  /// ```
  public var currentSignIn: SignIn? {
    clerk.client?.signIn
  }

  /// The current sign-up attempt, if any.
  ///
  /// This mirrors the in-progress `SignUp` stored on the current client.
  ///
  /// ```swift
  /// if let signUp = clerk.auth.currentSignUp {
  ///   // Continue the flow with the existing SignUp instance
  ///   _ = try await signUp.sendEmailCode()
  /// }
  /// ```
  public var currentSignUp: SignUp? {
    clerk.client?.signUp
  }

  /// The sessions on the current client.
  public var sessions: [Session] {
    clerk.client?.sessions ?? []
  }

  /// An `AsyncStream` of authentication events.
  ///
  /// Subscribe to this stream to receive notifications about sign-in completion, sign-up completion,
  /// sign-out, session changes, and token refreshes.
  ///
  /// ### Example:
  /// ```swift
  /// Task {
  ///     for await event in clerk.auth.events {
  ///         switch event {
  ///         case .signInCompleted(let signIn):
  ///             print("Sign in completed: \(signIn)")
  ///         case .signUpCompleted(let signUp):
  ///             print("Sign up completed: \(signUp)")
  ///         case .signedOut(let session):
  ///             print("Signed out: \(session)")
  ///         case .accountDeleted:
  ///             print("Account deleted")
  ///         case .sessionChanged(let oldValue, let newValue):
  ///             print("Session changed from \(oldValue?.id ?? "nil") to \(newValue?.id ?? "nil")")
  ///         case .tokenRefreshed(let token):
  ///             print("Token refreshed: \(token)")
  ///         }
  ///     }
  /// }
  /// ```
  public var events: AsyncStream<AuthEvent> {
    eventEmitter.events
  }

  /// Sends an auth event.
  ///
  /// This is internal to allow middleware to emit events while keeping the emitter private.
  func send(_ event: AuthEvent) {
    eventEmitter.send(event)
  }
}
