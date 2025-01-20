//
//  DeviceTokenSavingMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import SimpleKeychain

struct DeviceTokenSavingMiddleware {
    
    static func process(_ response: HTTPURLResponse) {
        
        // Set the device token from the response headers whenever received
        if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
            try? SimpleKeychain(accessibility: .afterFirstUnlockThisDeviceOnly)
                .set(deviceToken, forKey: "clerkDeviceToken")
        }
        
    }
    
}
