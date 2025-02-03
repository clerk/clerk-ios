//
//  FraudSettings.swift
//  Clerk
//
//  Created by Mike Pitre on 2/3/25.
//

import Foundation

extension Clerk.Environment {
    
    struct FraudSettings: Codable, Sendable {
        
        let native: Native
        
        struct Native: Codable, Sendable {
            let requireDeviceAttestation: Bool
        }
    }
}
