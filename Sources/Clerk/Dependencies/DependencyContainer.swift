import Foundation

/// Minimal dependency container owned by `Clerk`. This mirrors Superwall's
/// approach of a central object that wires up shared utilities.
final class DependencyContainer {

  private(set) var settings: Clerk.Settings
  private(set) var keychain: KeychainStore
  private(set) var apiClient: any APIClientProtocol
  private var isUsingCustomAPIClient = false

  init(
    settings: Clerk.Settings = .init(),
    frontendAPIURL: URL? = nil,
    apiClient: (any APIClientProtocol)? = nil,
    keychain: KeychainStore? = nil
  ) {
    self.settings = settings
    self.keychain = keychain ?? DependencyContainer.makeKeychain(config: settings.keychainConfig)
    if let apiClient {
      self.apiClient = apiClient
      self.isUsingCustomAPIClient = true
    } else {
      self.apiClient = DependencyContainer.makeApiClient(
        baseURL: frontendAPIURL
      )
      self.isUsingCustomAPIClient = false
    }
  }

  func updateSettings(_ settings: Clerk.Settings, keychain: KeychainStore? = nil) {
    self.settings = settings
    self.keychain = keychain ?? DependencyContainer.makeKeychain(config: settings.keychainConfig)
  }

  func updateFrontendAPIURL(_ frontendApiUrl: String) {
    let baseURL = URL(string: frontendApiUrl)
    guard isUsingCustomAPIClient == false else { return }
    self.apiClient = DependencyContainer.makeApiClient(
      baseURL: baseURL
    )
  }

  func overrideApiClient(_ client: some APIClientProtocol) {
    self.apiClient = client
    self.isUsingCustomAPIClient = true
  }

  func overrideKeychain(_ keychain: KeychainStore) {
    self.keychain = keychain
  }

  func resetApiClient(baseURL: URL?) {
    self.apiClient = DependencyContainer.makeApiClient(baseURL: baseURL)
    self.isUsingCustomAPIClient = false
  }
}

// MARK: - Helpers
private extension DependencyContainer {
  static func makeApiClient(
    baseURL: URL?
  ) -> APIClient {
    APIClient(baseURL: baseURL) { configuration in
      configuration.baseURL = baseURL
      configuration.encoder = .clerkEncoder
      configuration.decoder = .clerkDecoder
      configuration.defaultHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": "2025-04-10",
        "x-ios-sdk-version": Clerk.version,
        "x-mobile": "1"
      ]
      configuration.retryPolicy = RetryPolicy(maxAttempts: 3) { attempt in
        guard attempt > 1 else {
          return nil
        }

        // Exponential backoff: 200ms, 400ms, 800ms, ...
        let multiplier = 1 << (attempt - 2)
        return .milliseconds(200 * multiplier)
      }
      configuration.preprocessors = [
        ClerkHeaderRequestProcessor.self,
        ClerkQueryItemsRequestProcessor.self,
        ClerkURLEncodedFormEncoderRequestProcessor.self
      ]
      configuration.postprocessors = [
        ClerkDeviceTokenRequestProcessor.self,
        ClerkClientSyncRequestProcessor.self,
        ClerkEventEmitterRequestProcessor.self,
        ClerkErrorThrowingRequestProcessor.self,
        ClerkInvalidAuthRequestProcessor.self
      ]
      configuration.retriers = [
        ClerkDeviceAssertionRetrier.self
      ]
    }
  }

  static func makeKeychain(config: KeychainConfig) -> KeychainStore {
    KeychainStore(
      configuration: .init(
        service: config.service,
        accessGroup: config.accessGroup,
        accessibility: .afterFirstUnlockThisDeviceOnly
      )
    )
  }
}
