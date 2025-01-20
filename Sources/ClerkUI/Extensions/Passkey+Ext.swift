//
//  Passkey+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk

extension Passkey {
    
    static var mock: Passkey {
        .init(
            id: UUID().uuidString,
            name: "iCloud Keychain",
            lastUsedAt: .now,
            createdAt: .now,
            updatedAt: .now,
            verification: .init(
                status: .verified,
                strategy: "passkey",
                attempts: 0,
                expireAt: .now,
                error: nil,
                nonce: nil
            )
        )
    }
    
}
