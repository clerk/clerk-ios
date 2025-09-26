//
//  ClerkDeviceTokenRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkDeviceTokenRequestProcessor: RequestPostprocessor {
    static func process(response: HTTPURLResponse, data: Data, context: RequestPipelineContext) throws {
        if let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
            let keychain = Clerk.shared.dependencyContainer.keychain
            try? keychain.set(deviceToken, forKey: "clerkDeviceToken")
        }
    }
}
