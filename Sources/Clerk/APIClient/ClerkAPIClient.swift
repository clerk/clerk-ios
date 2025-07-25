//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import FactoryKit
import Foundation
import Get
import RequestBuilder

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {

  func client(_ client: APIClient, shouldRetry task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool {
    guard attempts == 1 else {
      return false
    }

    if try await DeviceAssertionMiddleware.process(task: task, error: error) {
      return true
    }

    if try await InvalidAuthMiddleware.process(task: task, error: error) {
      return true
    }

    return false
  }

}



extension Container {

  var apiClient: Factory<URLSessionManager> {
    self { BaseSessionManager(base: URL(""), session: .shared) }
      .cached
  }

}
