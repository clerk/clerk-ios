//
//  ClerkEventEmitterRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkEventEmitterRequestProcessor: RequestPostprocessor {
    
    static func process(response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        let shouldEmitSignedOutEvent = shouldEmitSignedOutEvent(response: response, task: task)

        Task {
            if let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response, signIn.status == .complete {
                await Clerk.shared.authEventEmitter.send(.signInCompleted(signIn: signIn))
            }

            if let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response, signUp.status == .complete {
                await Clerk.shared.authEventEmitter.send(.signUpCompleted(signUp: signUp))
            }

            if shouldEmitSignedOutEvent {
                await Clerk.shared.authEventEmitter.send(.signedOut)
            }
        }
    }

    private static func shouldEmitSignedOutEvent(response: HTTPURLResponse, task: URLSessionTask) -> Bool {
        guard (200..<300).contains(response.statusCode) else { return false }
        guard let request = task.originalRequest,
              let method = request.httpMethod?.uppercased(),
              let url = request.url else { return false }

        let path = url.path

        switch method {
        case "DELETE":
            return path == "/v1/client/sessions"
        case "POST":
            return path.hasPrefix("/v1/client/sessions/") && path.hasSuffix("/remove")
        default:
            return false
        }
    }
}
