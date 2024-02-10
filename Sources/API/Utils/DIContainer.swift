//
//  DIContainer.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation
import Factory
import Get
import KeychainAccess
import PhoneNumberKit

extension Container {
    var clerk: Factory<Clerk> {
        self { Clerk() }
            .singleton
    }
    
    var apiClient: Factory<APIClient> {
        self { APIClient.clerk }
            .singleton
    }
    
    var keychain: Factory<Keychain> {
        self { Keychain.clerk }
            .singleton
    }
    
    var phoneNumberKit: Factory<PhoneNumberKit> {
        self { PhoneNumberKit() }
            .singleton
    }
}
