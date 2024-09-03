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
        
        if await Clerk.shared.debugMode, let client = await Clerk.shared.client {
            request.setValue(client.id, forHTTPHeaderField: "x-clerk-client-id")
        }
        
        await request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
        
        request.url?.append(queryItems: [.init(name: "_is_native", value: "true")])
        request.url?.append(queryItems: [.init(name: "_clerk_js_version", value: "5.15.0")])

        // Encode body with url-encoded form
        if let data = request.httpBody {
            let json = try JSONDecoder.clerkDecoder.decode(JSON.self, from: data)
            request.httpBody = try URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
        }
    }
    
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        
        // Set the device token from the response headers whenever received
        if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
            try? SimpleKeychain(accessibility: .afterFirstUnlockThisDeviceOnly)
                .set(deviceToken, forKey: "clerkDeviceToken")
        }
        
        // If our response is an error status code...
        guard (200..<300).contains(response.statusCode) else {
            
            // ...and the response has a ClerkError body throw a custom clerk error
            if let clerkError = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data).errors.first {
                throw clerkError
            }

            // ...else throw a generic api error
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }
    
    func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool {
        
        if attempts == 1 {
            if let lastPathComponent = task.originalRequest?.url?.pathComponents.last, lastPathComponent != "client" {
                // if the original request wasn't a get client, try to get the client in sync with the server
                _ = try? await Client.get()
            }
            return true
        }
        
        return false
    }
    
}
