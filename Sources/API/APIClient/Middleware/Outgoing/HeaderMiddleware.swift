//
//  HeaderMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import SimpleKeychain

struct HeaderMiddleware {
    
    static func process(_ request: inout URLRequest) async throws {
        // Set the device token on every request
        if let deviceToken = try? SimpleKeychain().string(forKey: "clerkDeviceToken") {
            request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
        }
        
        if await Clerk.shared.debugMode, let client = await Clerk.shared.client {
            request.setValue(client.id, forHTTPHeaderField: "x-clerk-client-id")
        }
        
        await request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
    }
    
}
