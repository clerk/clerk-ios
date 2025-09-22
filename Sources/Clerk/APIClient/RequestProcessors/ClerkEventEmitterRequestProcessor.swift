//
//  ClerkEventEmitterRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkEventEmitterRequestProcessor: RequestPostprocessor {

    @MainActor
    private static var previousActiveSessionId: String?

    static func process(response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        Task { @MainActor in
            // Ensure any pending client synchronization runs before we inspect state.
            await Task.yield()

            if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response, signIn.status == .complete {
                await Clerk.shared.authEventEmitter.send(.signInCompleted(signIn: signIn))
            }

            if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response, signUp.status == .complete {
                await Clerk.shared.authEventEmitter.send(.signUpCompleted(signUp: signUp))
            }

            if shouldEmitSignedOutEvent(with: Clerk.shared.client) {
                await Clerk.shared.authEventEmitter.send(.signedOut)
            }

            previousActiveSessionId = Clerk.shared.client?.lastActiveSessionId
        }
    }

    @MainActor
    static func recordActiveSessionBeforeClientUpdate(_ client: Client?) {
        previousActiveSessionId = client?.lastActiveSessionId
    }

    @MainActor
    private static func shouldEmitSignedOutEvent(with client: Client?) -> Bool {
        guard let previousActiveSessionId else { return false }

        guard let client else {
            return true
        }

        if previousActiveSessionId == client.lastActiveSessionId {
            return false
        }

        if let previousSession = client.sessions.first(where: { $0.id == previousActiveSessionId }) {
            return previousSession.status != .active
        }

        return true
    }
}
