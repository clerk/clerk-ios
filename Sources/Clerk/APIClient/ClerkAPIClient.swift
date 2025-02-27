//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Factory
import Foundation
import Get

final class ClerkAPIClientDelegate: APIClientDelegate, Sendable {
  
  func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    await HeaderMiddleware.process(&request)
    QueryItemMiddleware.process(&request)
    try URLEncodedFormMiddleware.process(&request)
  }
  
  func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
    DeviceTokenSavingMiddleware.process(response)
    ClientSyncingMiddleware.process(data)
    EventEmitterMiddleware.process(data)
    try ErrorThrowingMiddleware.process(response, data: data)
  }
  
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
  
  var apiClient: Factory< APIClient> {
    self { APIClient(baseURL: URL(string: "")) }.cached
  }
  
}
