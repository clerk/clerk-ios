//
//  MockAPIClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import FactoryKit
import Foundation
import Get
import Mocker

@testable import Clerk

let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

extension Container: @retroactive AutoRegistering {

  public func autoRegister() {
    apiClient.context(.test) { _ in
        APIClient(baseURL: mockBaseUrl) { configuration in
            configuration.delegate = ClerkAPIClientDelegate()
            configuration.decoder = .clerkDecoder
            configuration.encoder = .clerkEncoder
            configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
            configuration.sessionConfiguration.httpAdditionalHeaders = [
                "Content-Type": "application/x-www-form-urlencoded",
                "clerk-api-version": "2024-10-01",
                "x-ios-sdk-version": Clerk.version,
                "x-mobile": "1"
            ]
        }
    }
  }

}
