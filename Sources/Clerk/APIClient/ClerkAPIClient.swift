//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Get
import SimpleKeychain
import Dependencies
import DependenciesMacros

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

@DependencyClient
struct APIClientProvider {
  var current: @Sendable () async throws -> APIClient
  var createClient: @Sendable (_ baseUrl: String) async throws -> APIClient
}

extension APIClientProvider: DependencyKey, TestDependencyKey {
  static var liveValue: APIClientProvider {
    let lastCreatedClient: LockIsolated<APIClient?> = .init(nil)
    
    return .init(
      current: { [lastCreatedClient] in
        guard let lastCreatedClient = lastCreatedClient.value else {
          dump("""
          You need to set the current API Client before accessing it. 
          You can do this by calling `client(for baseURL: String)`.
          """
          )
          
          throw ClerkClientError(message: "Current API Client has not been initialized.")
        }
        
        return lastCreatedClient
      },
      createClient: { [lastCreatedClient] baseUrl in
        let apiClient = APIClient(baseURL: URL(string: baseUrl)) { configuration in
          configuration.delegate = ClerkAPIClientDelegate()
          configuration.decoder = .clerkDecoder
          configuration.encoder = .clerkEncoder
        }
        lastCreatedClient.setValue(apiClient)
        return apiClient
      }
    )
  }
  
  static let testValue: APIClientProvider = Self()
}

extension DependencyValues {
  var apiClientProvider: APIClientProvider {
    get { self[APIClientProvider.self] }
    set { self[APIClientProvider.self] = newValue }
  }
}
