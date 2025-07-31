//
//  ClerkHeaderRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation

struct ClerkHeaderRequestProcessor: RequestPreprocessor {
    
    @MainActor
    static func process(request: inout URLRequest) async throws {
        // Set the device token on every request
        if let deviceToken = try? Container.shared.keychain().string(forKey: "clerkDeviceToken") {
            request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
        }
        
        if Clerk.shared.settings.debugMode, let client = Clerk.shared.client {
            request.setValue(client.id, forHTTPHeaderField: "x-clerk-client-id")
        }
        
        request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
    }
    
}
