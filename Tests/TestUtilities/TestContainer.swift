//
//  TestContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import FactoryKit
import Foundation

@testable import ClerkKit

let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

enum TestContainer {
  @MainActor
  static func reset() {
    // Always reset captured requests first
    RequestCaptureURLProtocol.reset()

    // Reset the container (this clears all FactoryKit registrations)
    Container.shared.reset()

    // Register in-memory keychain for tests FIRST
    // This needs to be registered before Clerk.configure() so Clerk uses it
    Container.shared.keychain.register {
      InMemoryKeychain() as any KeychainStorage
    }

    // Configure Clerk if not already configured
    if Clerk._shared == nil {
      Clerk.configure(publishableKey: "pk_test_dGVzdC5jbGVyay5hY2NvdW50cy5kZXYk")
    }

    // ALWAYS register API client with RequestCaptureURLProtocol AFTER Clerk configuration
    // This ensures our test protocol registration overrides Clerk's default API client
    // We register this every time, even if Clerk is already configured, to ensure
    // test isolation and that the protocol is always set up correctly
    Container.shared.apiClient.register {
      APIClient(baseURL: mockBaseUrl) { configuration in
        configuration.pipeline = Container.shared.networkingPipeline()
        configuration.decoder = .clerkDecoder
        configuration.encoder = .clerkEncoder
        // Create a fresh URLSessionConfiguration to avoid caching issues
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [RequestCaptureURLProtocol.self]
        sessionConfig.httpAdditionalHeaders = [
          "Content-Type": "application/x-www-form-urlencoded",
          "clerk-api-version": "2024-10-01",
          "x-ios-sdk-version": Clerk.version,
          "x-mobile": "1"
        ]
        configuration.sessionConfiguration = sessionConfig
      }
    }
  }
}

final class InMemoryKeychain: KeychainStorage {
  private let lock = NSLock()
  private var storage: [String: Data] = [:]

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    storage[key] = data
    lock.unlock()
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    let data = storage[key]
    lock.unlock()
    return data
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    storage.removeValue(forKey: key)
    lock.unlock()
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    let exists = storage[key] != nil
    lock.unlock()
    return exists
  }

  func string(forKey key: String) throws -> String? {
    guard let data = try data(forKey: key) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

extension InMemoryKeychain: @unchecked Sendable {}
