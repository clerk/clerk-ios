//
//  URLRequestInterceptorInvalidAuth.swift
//  Clerk
//
//  Created by Mike Pitre on 2/14/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorInvalidAuth: URLRequestInterceptor, @unchecked Sendable {

    var parent: URLSessionManager!

    func data(for request: URLRequest) async throws -> (Data?, HTTPURLResponse?) {
        let (data, response) = try await parent.data(for: request)

        if let response,
            response.isError,
            let data,
            let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
            let clerkAPIError = clerkErrorResponse.errors.first,
            ["authentication_invalid", "resource_not_found"].contains(clerkAPIError.code)
        {
            // If the original request was also a GET client, return so we don't end up in a loop of failed GET Clients.
            if request.url?.lastPathComponent == "client", request.httpMethod == "GET" {
                return (data, response)
            }

            // Try to get the client in sync.
            // If the client doesn't have a session on the server, this will set the local session to nil.
            try await Client.get()
        }

        return (data, response)
    }
}
