import FactoryKit
import Mocker

@testable import ClerkKit

enum TestContainer {
  static func reset() {
  Container.shared.reset()

  Container.shared.keychain.register {
    InMemoryKeychain() as any KeychainStorage
  }

  Container.shared.apiClient.register {
    APIClient(baseURL: mockBaseUrl) { configuration in
    configuration.pipeline = Container.shared.networkingPipeline()
    configuration.decoder = .clerkDecoder
    configuration.encoder = .clerkEncoder
    configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    configuration.sessionConfiguration.httpAdditionalHeaders = [
      "Content-Type": "application/x-www-form-urlencoded",
      "clerk-api-version": "2024-10-01",
      "x-ios-sdk-version": Clerk.version,
      "x-mobile": "1"
    ]
    }
  }
  }
}
