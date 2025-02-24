//
//  MockAPIClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import Foundation
import Mocker

@testable import Clerk
@testable import Get

let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

extension APIClient {
  static let mock: APIClient = .init(
    baseURL: mockBaseUrl,
    { configuration in
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.delegate = ClerkAPIClientDelegate()
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    }
  )

}
