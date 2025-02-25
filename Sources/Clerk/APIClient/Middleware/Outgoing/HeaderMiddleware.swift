//
//  HeaderMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import SimpleKeychain

struct HeaderMiddleware {
  
  @MainActor
  static func process(_ request: inout URLRequest) async {
    
    if request.value(forHTTPHeaderField: "Content-Type") == nil {
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
    
    request.setValue("2024-10-01", forHTTPHeaderField: "clerk-api-version")
    request.setValue(Clerk.version, forHTTPHeaderField: "x-ios-sdk-version")

    #if os(iOS)
    request.setValue("1", forHTTPHeaderField: "x-mobile")
    #endif
    
    // Set the device token on every request
    if let deviceToken = try? SimpleKeychain().string(forKey: "clerkDeviceToken") {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }
    
    if Clerk.shared.debugMode, let client = Clerk.shared.client {
      request.setValue(client.id, forHTTPHeaderField: "x-clerk-client-id")
    }
    
    request.setValue(deviceID, forHTTPHeaderField: "x-native-device-id")
  }
  
}
