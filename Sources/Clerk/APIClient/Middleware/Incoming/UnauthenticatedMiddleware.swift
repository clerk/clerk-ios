//
//  UnauthenticatedMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 2/14/25.
//

import Foundation
import Get

struct UnauthenticatedMiddleware {
    
    static func process(task: URLSessionTask, error: any Error) async throws -> Bool {
        
        if let clerkAPIError = error as? ClerkAPIError, clerkAPIError.code == "authentication_invalid" {
            
            // If the original request was also a GET client, return false so we don't end up in a loop of failed GET Clients.
            if task.originalRequest?.url?.lastPathComponent == "client", task.originalRequest?.httpMethod == "GET" {
                return false
            }
            
            // Try to get the client in sync.
            // If the client doesn't have a session on the server, this will set the local session to nil.
            try await Client.get()
        }
        
        return false
    }
    
}
