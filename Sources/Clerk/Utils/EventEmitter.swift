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
final public class EventEmitter<Event: Sendable> {

    /// A dictionary of active AsyncStream continuations keyed by UUID.
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    /// Returns a new `AsyncStream` that receives all future events.
    ///
    /// Each consumer that calls this method will receive its own stream of events.
    /// When a consumer finishes or cancels the stream, its continuation is removed.
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
        let id = UUID()

        // Capture a weak reference to self to avoid strong reference cycles
        weak var weakSelf = self

        return AsyncStream<Event> { continuation in
            // Store the continuation for broadcasting
            self.continuations[id] = continuation

            // Clean up when the stream is terminated
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    weakSelf?.continuations.removeValue(forKey: id)
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
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
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
    case signedOut
}
