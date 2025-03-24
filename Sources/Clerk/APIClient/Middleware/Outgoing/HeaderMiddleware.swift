//
//  HeaderMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Factory
import Foundation

struct HeaderMiddleware {
  
  @MainActor
  static func process(_ request: inout URLRequest) async {
    
    // Set the device token on every request
    if let deviceToken = try? Container.shared.keychain().string(forKey: "clerkDeviceToken") {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }
    
    if Clerk.shared.debugMode, let client = Clerk.shared.client {
      request.setValue(client.id, forHTTPHeaderField: "x-clerk-client-id")
    }
    
    request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
  }
  
}
