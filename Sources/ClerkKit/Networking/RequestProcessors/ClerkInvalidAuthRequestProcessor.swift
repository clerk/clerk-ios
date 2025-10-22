//
//  ClerkInvalidAuthRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 2/14/25.
//

import Foundation

// When we get an invalid auth error, do a get client to sync the latest state from the server

struct ClerkInvalidAuthRequestProcessor: RequestPostprocessor {
    static func process(response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
            let clerkAPIError = clerkErrorResponse.errors.first,
            clerkAPIError.code == "authentication_invalid"
        {
            // If the original request was also a GET client, return so we don't end up in a loop of failed GET Clients.
            if task.originalRequest?.url?.lastPathComponent == "client", task.originalRequest?.httpMethod == "GET" {
                return
            }
            
            Task {
                try await Client.get()
            }
        }
    }
}
