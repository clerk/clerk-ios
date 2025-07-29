//
//  URLRequestInterceptorEventEmitter.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorEventEmitter: URLRequestInterceptor, @unchecked Sendable {

    var parent: URLSessionManager!

    func data(for request: URLRequest) async throws -> (Data?, HTTPURLResponse?) {
        let (data, response) = try await parent.data(for: request)

        if let data, let signIn = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignIn>.self, from: data).response, signIn.status == .complete {
            await Clerk.shared.authEventEmitter.send(.signInCompleted(signIn: signIn))
        }

        if let data, let signUp = try? JSONDecoder.clerkDecoder.decode(ClientResponse<SignUp>.self, from: data).response, signUp.status == .complete {
            await Clerk.shared.authEventEmitter.send(.signUpCompleted(signUp: signUp))
        }

        return (data, response)
    }

}
