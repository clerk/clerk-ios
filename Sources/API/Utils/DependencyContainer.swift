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
    
    var apiClient: ParameterFactory<String, APIClient> {
        self {
            APIClient(baseURL: URL(string: $0)) { client in
                client.delegate = ClerkAPIClientDelegate()
                client.decoder = JSONDecoder.clerkDecoder
                client.encoder = JSONEncoder.clerkEncoder
                client.sessionConfiguration.httpAdditionalHeaders = [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "User-Agent": UserAgentHelpers.userAgentString,
                    "clerk-api-version": "2021-02-05",
                    "x-ios-sdk-version": ClerkSDK.version
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
