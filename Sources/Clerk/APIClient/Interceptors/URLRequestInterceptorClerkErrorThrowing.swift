//
//  URLRequestInterceptorClerkErrorThrowing.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorClerkErrorThrowing: URLRequestInterceptor, @unchecked Sendable {

    var parent: URLSessionManager!

    func data(for request: URLRequest) async throws -> (Data?, HTTPURLResponse?) {
        let (data, response) = try await parent.data(for: request)

        if let response, response.isError {

            // ...and the response has a ClerkError body throw a custom clerk error
            if let data,
                let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
                var clerkAPIError = clerkErrorResponse.errors.first
            {
                clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId
                ClerkLogger.logNetworkError(
                    clerkAPIError,
                    endpoint: response.url?.absoluteString ?? "unknown",
                    statusCode: response.statusCode
                )
                throw clerkAPIError
            }

            // ...else throw a generic api error
            let error = URLError(.badServerResponse)
            ClerkLogger.logNetworkError(
                error,
                endpoint: response.url?.absoluteString ?? "unknown",
                statusCode: response.statusCode
            )
            throw error
        }

        // fallback
        return (data, response)
    }
}
