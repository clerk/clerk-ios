//
//  EventEmitter.swift
//  Clerk
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
final class EventEmitter<Event: Sendable> {
  /// Active continuations that need to receive events.
  /// Each call to `events` creates a new continuation that must be retained
  /// until the stream terminates.
  private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

  init() {}

  var events: AsyncStream<Event> {
    let (stream, continuation) = AsyncStream<Event>.makeStream()
    let id = UUID()
    continuations[id] = continuation

    continuation.onTermination = { @Sendable [weak self] _ in
      Task { @MainActor in
        self?.continuations.removeValue(forKey: id)
      }
    }

    return stream
  }

  func send(_ event: Event) {
    for continuation in continuations.values {
      continuation.yield(event)
    }
  }

  func finish() {
    let activeContinuations = continuations.values
    continuations.removeAll()

    for continuation in activeContinuations {
      continuation.finish()
    }
  }
}
