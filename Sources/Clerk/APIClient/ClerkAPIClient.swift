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
import Mocker

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

actor APIClientCache {
  static var shared = APIClientCache()
  
  private var cache: [URL: APIClient] = [:]
  private var _current: APIClient?
  
  var current: APIClient {
    get throws {
      guard let _current else {
        dump("""
        You need to set the current API Client before accessing it. 
        You can do this by calling `client(for baseURL: String)`.
        """
        )
        
        throw ClerkClientError(
          message: "Current API Client has not been initialized."
        )
      }
      
      return _current
    }
  }
  
  private func setCurrent(client: APIClient) {
    _current = client
  }
  
  func client(for baseURL: String) throws -> APIClient {
    guard let url = URL(string: baseURL) else {
      throw ClerkClientError(message: "Invalid base URL.")
    }
    
    if let cachedClient = cache[url] {
      return cachedClient
    } else {
      let newClient = APIClient(baseURL: url) { configuration in
        configuration.delegate = ClerkAPIClientDelegate()
        configuration.decoder = .clerkDecoder
        configuration.encoder = .clerkEncoder
      }
      cache[url] = newClient
      setCurrent(client: newClient)
      return newClient
    }
  }
  
}

@DependencyClient
struct APIClientProvider {
  var current: @Sendable () async throws -> APIClient
  var client: @Sendable (_ baseUrl: String) async throws -> APIClient
}

extension APIClientProvider: DependencyKey, TestDependencyKey {
  static var liveValue: APIClientProvider {
    .init(
      current: {
        try await APIClientCache.shared.current
      },
      client: { baseUrl in
        try await APIClientCache.shared.client(for: baseUrl)
      }
    )
  }
  
  static var previewValue: APIClientProvider {
    .init(
      current: { .mock },
      client: { _ in .mock }
    )
  }
  
  static var testValue: APIClientProvider {
    .init(
      current: { .mock },
      client: { _ in .mock }
    )
  }
}

extension DependencyValues {
  var apiClientProvider: APIClientProvider {
    get { self[APIClientProvider.self] }
    set { self[APIClientProvider.self] = newValue }
  }
}

extension APIClient {
  
  static let mockBaseUrl = URL(string: "https://clerk.mock.dev")!
  
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
