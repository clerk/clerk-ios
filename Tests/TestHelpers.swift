import FactoryKit
import Foundation
import Mocker

@testable import ClerkKit

let mockBaseUrl = URL(string: "https://mock.clerk.accounts.dev")!

/// Test publishable key that decodes to mock.clerk.accounts.dev
let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

/// Configures Clerk for testing and registers the API client with MockingURLProtocol.
/// This ensures that HTTP requests are intercepted by Mocker instead of reaching the real API.
@MainActor
func configureClerkForTesting() {
  Clerk.configure(publishableKey: testPublishableKey)
  registerMockingAPIClient()
}

/// Re-registers the API client with MockingURLProtocol after Clerk.configure() overrides it.
/// This ensures that HTTP requests are intercepted by Mocker instead of reaching the real API.
private func registerMockingAPIClient() {
  Container.shared.apiClient.register {
    APIClient(baseURL: mockBaseUrl) { configuration in
      configuration.pipeline = Container.shared.networkingPipeline()
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": "2025-04-10",
        "x-ios-sdk-version": Clerk.version,
        "x-mobile": "1"
      ]
    }
  }
}
