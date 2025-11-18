//
//  EventEmitter.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import Combine

/// A generic class for broadcasting strongly typed events to multiple asynchronous consumers.
///
/// `EventEmitter` allows you to emit events of a specific type and provides
/// individual `AsyncStream`s to multiple listeners. Each call to `events`
/// returns a new stream that will receive all future events emitted by the emitter.
///
/// This implementation supports multiple concurrent consumers,
/// making it suitable for event broadcasting scenarios.
///
/// ### Example:
/// ```swift
/// let emitter = EventEmitter<AuthEvent>()
///
/// Task {
///     for await event in emitter.events {
///         // Handle the event
///     }
/// }
/// ```
///
/// You can emit events using `send(_:)`:
/// ```swift
/// emitter.send(.signInCompleted(signIn: signIn))
/// ```
@MainActor
public final class EventEmitter<Event: Sendable> {
  /// The Combine subject that broadcasts events to all subscribers.
  ///
  /// Using `PassthroughSubject` allows multiple subscribers to receive
  /// the same events without storing a current value.
  private let subject = PassthroughSubject<Event, Never>()

  /// Returns a new `AsyncStream` that receives all future events.
  ///
  /// Each consumer that calls this method will receive its own stream of events.
  /// The stream is backed by a Combine publisher, allowing multiple concurrent
  /// consumers to receive the same events.
  ///
  /// ### Example:
  /// ```swift
  /// Task {
  ///     for await event in emitter.events {
  ///         // Handle the event
  ///     }
  /// }
  /// ```
  public var events: AsyncStream<Event> {
    // Convert the Combine publisher to an AsyncSequence using .values
    // and wrap it in an AsyncStream to maintain the public API
    return AsyncStream<Event> { continuation in
      let task = Task {
        for await event in subject.values {
          continuation.yield(event)
        }
        continuation.finish()
      }

      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }

  /// Sends an event to all active listeners.
  ///
  /// - Parameter event: The event to emit to all active streams.
  ///
  /// ### Example:
  /// ```swift
  /// emitter.send(.signUpCompleted(signUp: signUp))
  /// ```
  public func send(_ event: Event) {
    subject.send(event)
  }

  /// Finishes all active event streams and removes all consumers.
  ///
  /// Use this to cleanly shut down the event emitter.
  public func finish() {
    subject.send(completion: .finished)
  }
}

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
  /// The device token was received from the API.
  case deviceTokenReceived(token: String)
}
