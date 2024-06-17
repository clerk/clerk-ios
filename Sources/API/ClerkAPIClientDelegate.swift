//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
import SimpleKeychain

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {
    
    func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
        // Set the device token on every request
        if let deviceToken = try? SimpleKeychain().string(forKey: "clerkDeviceToken") {
            request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
        }
        
        request.url?.append(queryItems: [.init(name: "_is_native", value: "true")])
        request.url?.append(queryItems: [.init(name: "_clerk_js_version", value: "4.70.0")])

        // Encode body with url-encoded form
        if let data = request.httpBody {
            let json = try JSONDecoder.clerkDecoder.decode(JSON.self, from: data)
            request.httpBody = try URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
        }
    }
    
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        // If our response is an error status code...
        guard (200..<300).contains(response.statusCode) else {
            
            // ...and the response has a ClerkError body throw a custom clerk error
            if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
                let clerkError = clerkErrorResponse.errors.first {
                
                if response.statusCode == 401 {
                    Task { try? await Clerk.shared.signOut(sessionId: Clerk.shared.session?.id) }
                }
                
                throw clerkError
            }

            // ...else throw a generic api error
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
        
        // Set the device token from the response headers whenever recieved in the response headers
        if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
            try? SimpleKeychain(accessibility: .afterFirstUnlockThisDeviceOnly)
                .set(deviceToken, forKey: "clerkDeviceToken")
        }
    }
    
}
