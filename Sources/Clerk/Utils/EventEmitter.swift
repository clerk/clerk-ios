//
//  EventEmitter.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

/// A generic class for broadcasting events using an async sequence.
///
/// `EventEmitter` allows you to emit strongly typed events and provides an `AsyncStream`
/// to listen for those events asynchronously.
///
/// You can use the `events` stream to listen for events emitted by the `EventEmitter`.
/// For example, you can iterate over the stream using `for await` to handle each event as it occurs.
///
/// ### Example:
/// ```swift
/// Task {
///     for await event in emitter.events {
///         // Handle the event
///     }
/// }
/// ```
@MainActor
final public class EventEmitter<Event: Sendable> {
    
    /// The continuation for managing the flow of events in the `AsyncStream`.
    private var continuation: AsyncStream<Event>.Continuation?
    
    /// An asynchronous stream of events.
    ///
    /// You can use this stream to listen for events emitted by the `EventEmitter`.
    /// For example, you can iterate over the stream using `for await` to handle each event as it occurs.
    ///
    ///### Example:
    /// ```swift
    /// Task {
    ///     for await event in emitter.events {
    ///         // Handle the event
    ///     }
    /// }
    /// ```
    public var events: AsyncStream<Event> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    /// Sends an event to all active listeners of the `events` stream.
    ///
    /// - Parameter event: The event to emit to the stream.
    ///
    /// Use this method to broadcast events to listeners. Any listeners that are iterating over
    /// the `events` stream will receive the emitted event.
    ///
    ///### Example:
    /// ```swift
    /// emitter.send(.someEvent)
    /// ```
    func send(_ event: Event) {
        continuation?.yield(event)
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
}



