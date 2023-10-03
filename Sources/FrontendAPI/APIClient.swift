//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
import KeychainAccess

extension Clerk {
    
    /// The Clerk API Client
    static let client = APIClient(baseURL: URL(string: frontendAPIURL)) { client in
        client.delegate = ClerkAPIClientDelegate()
    }
    
}

final class ClerkAPIClientDelegate: APIClientDelegate {
    
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        // Set the auth token on every request
        if let authToken = Clerk.keychain[Clerk.KeychainKey.authToken] {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Required for native application flow on all requests
        request.url?.append(queryItems: [.init(name: "_is_native", value: "true")])
    }
    
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        // Set the auth token from the response headers on every request
        if let authToken = response.value(forHTTPHeaderField: "Authorization") {
            Clerk.keychain[Clerk.KeychainKey.authToken] = authToken
        }
    }
}

extension Clerk {
    
    static let keychain = Keychain(service: "com.clerk")
    
    enum KeychainKey {
        static let authToken = "authToken"
    }
}
