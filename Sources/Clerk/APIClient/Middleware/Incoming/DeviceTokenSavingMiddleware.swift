//
//  DeviceTokenSavingMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Factory
import Foundation

struct DeviceTokenSavingMiddleware {
    
    static func process(_ response: HTTPURLResponse) {
        
        // Set the device token from the response headers whenever received
        if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
          try? Container.shared.keychain().set(deviceToken, forKey: "clerkDeviceToken")
        }
        
    }
    
}
