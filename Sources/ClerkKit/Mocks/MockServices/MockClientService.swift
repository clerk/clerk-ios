//
//  MockClientService.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

package final class MockClientService: ClientServiceProtocol {
  package nonisolated(unsafe) var getHandler: (() async throws -> Client?)?

  package init(get: (() async throws -> Client?)? = nil) {
    getHandler = get
  }

  @MainActor
  package func getResponse(skipClientId _: Bool = false) async throws -> ClientServiceResponse {
    if let handler = getHandler {
      return try await ClientServiceResponse(
        client: handler(),
        requestSequence: nil,
        serverDate: nil
      )
    }
    return ClientServiceResponse(
      client: .mock,
      requestSequence: nil,
      serverDate: nil
    )
  }
}
