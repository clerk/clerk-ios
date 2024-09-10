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
    
    private var additionalHeaders: [String: any Encodable] {
        var headers = [
            "Content-Type": "application/x-www-form-urlencoded",
            "clerk-api-version": "2021-02-05",
            "x-ios-sdk-version": ClerkSDK.version
        ]
        
        #if os(iOS)
        headers["x-mobile"] = "1"
        #endif
        
        return headers
    }
    
    var apiClient: ParameterFactory<String, APIClient> {
        self {
            APIClient(baseURL: URL(string: $0)) { client in
                client.delegate = ClerkAPIClientDelegate()
                client.decoder = JSONDecoder.clerkDecoder
                client.encoder = JSONEncoder.clerkEncoder
                client.sessionConfiguration.httpAdditionalHeaders = self.additionalHeaders
            }
        }
        .cached
    }
    
    var phoneNumberKit: Factory<PhoneNumberKit> {
        self { PhoneNumberKit() }
            .cached
    }
    
}
