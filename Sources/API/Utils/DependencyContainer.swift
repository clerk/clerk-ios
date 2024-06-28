//
//  DependencyContainer.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation
import Factory
import Get
import PhoneNumberKit

extension Container {
    
    var clerk: Factory<Clerk> {
        self { Clerk() }
            .singleton
    }
    
    var apiClient: Factory<APIClient> {
        self {
            APIClient(baseURL: URL(string: Clerk.shared.frontendAPIURL)) { client in
                client.delegate = ClerkAPIClientDelegate()
                client.decoder = JSONDecoder.clerkDecoder
                client.encoder = JSONEncoder.clerkEncoder
                client.sessionConfiguration.httpAdditionalHeaders = [
                    "clerk-api-version": "2021-02-05",
                    "x-ios-sdk-version": ClerkSDK.version,
                    "x-native-device-id": deviceID,
                    "Content-Type": "application/x-www-form-urlencoded",
                    "User-Agent": UserAgentHelpers.userAgentString
                ]
            }
        }
        .cached
    }
    
    var phoneNumberKit: Factory<PhoneNumberKit> {
        self { PhoneNumberKit() }
            .cached
    }
    
}

extension Container: @retroactive AutoRegistering {
    
    public func autoRegister() {
        Container.shared.clerk.register {
            Clerk()
        }
        
        Container.shared.clerk.context(.preview) {
            Clerk()
        }
    }
    
}
