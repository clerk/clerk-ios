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
    static let apiClient = APIClient(baseURL: URL(string: Clerk.shared.frontendAPIURL)) { client in
        client.delegate = ClerkAPIClientDelegate()
        client.decoder = JSONDecoder.snakeCaseDecoder
        client.sessionConfiguration.httpAdditionalHeaders = [
            "Content-Type": "application/x-www-form-urlencoded"
        ]
    }
    
}

final class ClerkAPIClientDelegate: APIClientDelegate {
    
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        // Set the auth token on every request
        if let authToken = Clerk.keychain[Clerk.KeychainKey.authToken] {
            request.setValue(authToken, forHTTPHeaderField: "Authorization")
        }
        
        // Required for native application flow on all requests
        request.url?.append(queryItems: [.init(name: "_is_native", value: "true")])
        
        // Encode body with url-encoded form
        if let data = request.httpBody {
            let json = try JSONDecoder.snakeCaseDecoder.decode(JSON.self, from: data)
            request.httpBody = try URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
        }
    }
    
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        // If our response is an error status code...
        guard (200..<300).contains(response.statusCode) else {
            // and the response has a ClerkError body throw a custom clerk error
            if let clerkErrorResponse = try? JSONDecoder.snakeCaseDecoder.decode(ClerkErrorResponse.self, from: data),
                let clerkError = clerkErrorResponse.errors.first {
                throw clerkError
            }

            // else throw a generic api error
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
        
        // Set the auth token from the response headers whenever recieved in the response headers
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
