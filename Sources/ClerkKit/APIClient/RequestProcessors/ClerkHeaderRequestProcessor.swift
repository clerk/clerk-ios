//
//  ClerkHeaderRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkHeaderRequestProcessor: RequestPreprocessor {
    
    @MainActor
    static func process(request: inout URLRequest) async throws {
        // Set the device token on every request
        let keychain = Clerk.shared.dependencyContainer.keychain
        if let deviceToken = try? keychain.string(forKey: "clerkDeviceToken") {
            request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
        }
        
        if Clerk.shared.dependencyContainer.settings.debugMode, let client = Clerk.shared.client {
            request.setValue(client.id, forHTTPHeaderField: "x-clerk-client-id")
        }
        
        request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
    }
    
}
