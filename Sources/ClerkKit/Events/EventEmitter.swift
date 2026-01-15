//
//  EventEmitter.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

/// A generic class for broadcasting strongly typed events to multiple asynchronous consumers.
///
/// `EventEmitter` allows you to emit events of a specific type and provides
/// individual `AsyncStream`s to multiple listeners. Each call to `events`
/// returns a new stream that will receive all future events emitted by the emitter.
///
/// This implementation supports multiple concurrent consumers,
/// making it suitable for event broadcasting scenarios. All operations are
/// MainActor-isolated for thread safety.
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
///
@MainActor
public final class EventEmitter<Event: Sendable> {
  /// Active continuations that need to receive events.
  /// Each call to `events` creates a new continuation that must be retained
  /// until the stream terminates.
  private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

  public init() {}

  /// Returns a new `AsyncStream` that receives all future events.
  ///
  /// Each consumer that calls this method will receive its own stream of events.
  /// The stream uses modern Swift concurrency with AsyncStream continuations.
  ///
  /// ### Example:
  /// ```swift
  /// Task {
  ///     for await event in emitter.events {
  ///         // Handle the event
  ///     }
  /// }
  /// ```
  ///
  public var events: AsyncStream<Event> {
    AsyncStream<Event> { continuation in
      let id = UUID()
      continuations[id] = continuation

      continuation.onTermination = { @Sendable [weak self] _ in
        Task { @MainActor in
          self?.continuations.removeValue(forKey: id)
        }
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
    for continuation in continuations.values {
      continuation.yield(event)
    }
  }

  /// Finishes all active event streams and removes all consumers.
  ///
  /// Use this to cleanly shut down the event emitter.
  public func finish() {
    let activeContinuations = continuations.values
    continuations.removeAll()

    for continuation in activeContinuations {
      continuation.finish()
    }
  }
}
