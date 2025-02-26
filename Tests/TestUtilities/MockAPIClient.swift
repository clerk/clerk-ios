//
//  MockAPIClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Factory
import Foundation
import Get
import Mocker

@testable import Clerk

let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

extension APIClient {
  static let mock: APIClient = .init(
    baseURL: mockBaseUrl,
    { configuration in
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.delegate = ClerkAPIClientDelegate()
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "x-mobile": "1",
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": "2024-10-01",
        "x-ios-sdk-version": Clerk.version
      ]
    }
  )

}

extension Container: @retroactive AutoRegistering {
  
  public func autoRegister() {
    apiClient.context(.test) { _ in .mock }
  }
  
}
