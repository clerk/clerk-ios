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

actor APIClientCache {
  static var shared = APIClientCache()
  
  var cache: [URL: APIClient] = [:]
  
  // Dummy initialized value.
  // If attempted to be accessed will throw assertion error.
  private var _current: APIClient = .preview
  
  var current: APIClient {
    get {
      assert(
        _current.configuration.baseURL == APIClient.preview.configuration.baseURL,
        "You must call `client(for baseURL: URL)` at least once before accessing current."
      )
      return _current
    }
    set {
      _current = newValue
    }
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
      current = newClient
      return newClient
    }
  }
  
}

extension APIClient {
  static var preview: Self {
    .init(baseURL: URL(string: "https://api.example.com")!) { configuration in
      configuration.delegate = ClerkAPIClientDelegate()
      configuration.encoder = .clerkEncoder
      configuration.decoder = .clerkDecoder
    }
  }
}

@DependencyClient
struct APIClientProvider {
  var current: @Sendable () async -> APIClient = { .preview }
  var client: @Sendable (_ baseUrl: String) async throws -> APIClient
}

extension APIClientProvider: DependencyKey, TestDependencyKey {
  static var liveValue: APIClientProvider {
    .init(
      current: {
        await APIClientCache.shared.current
      },
      client: { baseUrl in
        try await APIClientCache.shared.client(for: baseUrl)
      }
    )
  }
  
  static var previewValue: APIClientProvider {
    .init(
      current: { .preview },
      client: { _ in .preview }
    )
  }
}

extension DependencyValues {
  var apiClientProvider: APIClientProvider {
    get { self[APIClientProvider.self] }
    set { self[APIClientProvider.self] = newValue }
  }
}
