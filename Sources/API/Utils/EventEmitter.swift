//
//  EventEmitter.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

extension Clerk {
    static public let authEventEmitter = EventEmitter<AuthEvent>()
}

final public class EventEmitter<Event> {
    private var continuation: AsyncStream<Event>.Continuation?
    
    public var events: AsyncStream<Event> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    func send(_ event: Event) {
        continuation?.yield(event)
    }
}

public enum AuthEvent {
    case signInCompleted(signIn: SignIn)
    case signUpCompleted(signUp: SignUp)
}


