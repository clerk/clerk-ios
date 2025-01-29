//
//  EventEmitterMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct EventEmitterMiddleware {
    
    static func process(_ data: Data) {
        Task {
            if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response, signIn.status == .complete {
                await Clerk.shared.authEventEmitter.send(.signInCompleted(signIn: signIn))
            }
            
            if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response, signUp.status == .complete {
                await Clerk.shared.authEventEmitter.send(.signUpCompleted(signUp: signUp))
            }
        }
    }
    
}
