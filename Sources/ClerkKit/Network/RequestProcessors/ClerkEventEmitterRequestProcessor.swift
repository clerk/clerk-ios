//
//  ClerkEventEmitterRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkEventEmitterRequestProcessor: RequestPostprocessor {

    static func process(response: HTTPURLResponse, data: Data, context: RequestPipelineContext) throws {
        Task { @MainActor in
            if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response, signIn.status == .complete {
                Clerk.shared.authEventEmitter.send(.signInCompleted(signIn: signIn))
            }

            if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response, signUp.status == .complete {
                Clerk.shared.authEventEmitter.send(.signUpCompleted(signUp: signUp))
            }

            if let session = try? JSONDecoder.clerkDecoder.decode(ClientResponse<Session>.self, from: data).response, session.status == .removed {
                Clerk.shared.authEventEmitter.send(.signedOut(session: session))
            }
        }
    }
}
