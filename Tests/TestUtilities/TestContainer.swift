//
//  TestContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import FactoryKit
import FactoryTesting
import Foundation

@testable import ClerkKit

let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

enum TestContainer {
  // Lock to ensure atomic reset operations
  private static let resetLock = NSLock()

  @MainActor
  static func reset() {
    // Use a lock to ensure reset operations are atomic
    // This prevents race conditions when multiple tests run in parallel
    resetLock.lock()
    defer { resetLock.unlock() }

    Clerk._resetForTesting()

    // Always reset captured requests first
    // This marks the start of this test's capture period without clearing other tests' requests
    RequestCaptureURLProtocol.reset()

    // Reset the container (this clears all FactoryKit registrations and cached instances)
    // This is critical - it clears any cached APIClient instances from previous tests
    // FactoryTesting provides enhanced reset capabilities through Container.shared.reset()
    Container.shared.reset()

    // Register in-memory keychain for tests FIRST
    // This needs to be registered before Clerk.configure() so Clerk uses it
    Container.shared.keychain.register {
      InMemoryKeychain() as any KeychainStorage
    }

    // Register test API client BEFORE Clerk configuration
    // This ensures our test protocol is registered before Clerk tries to register its own
    // Using FactoryTesting's register mechanism ensures test registrations override cached instances
    // CRITICAL: Create a fresh NetworkingPipeline directly instead of resolving from Container
    // to avoid any cached instances from interfering with test isolation
    // IMPORTANT: This registration happens BEFORE any code resolves apiClient, ensuring our test version is used
    Container.shared.apiClient.register {
      APIClient(baseURL: mockBaseUrl) { configuration in
        configuration.pipeline = .clerkDefault
        configuration.decoder = .clerkDecoder
        configuration.encoder = .clerkEncoder
        // Create a fresh URLSessionConfiguration to avoid caching issues
        // Use ephemeral to prevent any URLSession caching
        let sessionConfig = URLSessionConfiguration.ephemeral
        // Ensure protocolClasses is set BEFORE creating URLSession
        // This must be set as an array with our protocol first
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

    // Configure Clerk if not already configured
    // Note: Clerk.configure() will try to register its own apiClient, but our registration above
    // happens first, so Clerk's registration will override ours - we need to re-register after
    if Clerk._shared == nil {
      Clerk.configure(publishableKey: "pk_test_dGVzdC5jbGVyay5hY2NvdW50cy5kZXYk")
      // Re-register our test API client AFTER Clerk.configure() to ensure it overrides Clerk's
      // Clerk.configure() registers its own apiClient, so we need to override it
      // CRITICAL: This must happen after Clerk.configure() or Clerk's registration will override ours
      // CRITICAL: Create a fresh NetworkingPipeline directly instead of resolving from Container
      // to avoid any cached instances from interfering with test isolation
      Container.shared.apiClient.register {
        APIClient(baseURL: mockBaseUrl) { configuration in
          configuration.pipeline = .clerkDefault
          configuration.decoder = .clerkDecoder
          configuration.encoder = .clerkEncoder
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
    } else {
      // Reset Clerk.shared state to ensure test isolation
      Clerk.shared.client = nil
      Clerk.shared.sessionsByUserId = [:]
      Clerk.shared.environment = Clerk.Environment()
      // CRITICAL: Even though Clerk is already configured, we need to ensure
      // the test API client is registered. Since Container was reset above,
      // Clerk's original apiClient registration is gone, so our registration above should work.
      // But let's also ensure we register again here to be safe.
      // CRITICAL: Create a fresh NetworkingPipeline directly instead of resolving from Container
      // to avoid any cached instances from interfering with test isolation
      Container.shared.apiClient.register {
        APIClient(baseURL: mockBaseUrl) { configuration in
          configuration.pipeline = .clerkDefault
          configuration.decoder = .clerkDecoder
          configuration.encoder = .clerkEncoder
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
