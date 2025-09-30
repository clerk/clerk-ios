import Foundation

/// Central dependency container owned by `Clerk`.
final class DependencyContainer {
  var configurationStore: ConfigurationStore
  var options: ClerkOptions
  var keychain: KeychainStore
  var apiClient: (any APIClientProtocol)
  var telemetry: TelemetryCollector
  var authEventEmitter: EventEmitter<AuthEvent>
  var configManager: ConfigManager
  var appLifecycleManager: AppLifecycleManager

  init(options: ClerkOptions? = nil) {
    self.options = options ?? ClerkOptions()
    self.configurationStore = ConfigurationStore()
    self.keychain = DependencyContainer.makeKeychain(options: self.options.keychain)
    self.apiClient = DependencyContainer.makeApiClient(baseURL: configurationStore.frontendAPIURL)
    self.telemetry = DependencyContainer.makeTelemetryCollector()
    self.authEventEmitter = DependencyContainer.makeAuthEventEmitter()

    let fetcher = DefaultConfigFetcher(
      configurationStore: configurationStore,
      optionsProvider: { [weak self] in
        self?.options ?? ClerkOptions()
      }
    )
    self.configManager = ConfigManager(fetcher: fetcher)

    Task { await self.configManager.load() }

    self.appLifecycleManager = AppLifecycleManager(
      notificationCenter: .default,
      telemetry: telemetry
    )
  }

  // MARK: - Public Helpers

}

// MARK: - Internal Factory Helpers
extension DependencyContainer {
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

  static func makeKeychain(options: ClerkOptions.Keychain) -> KeychainStore {
    KeychainStore(
      configuration: .init(
        service: options.service,
        accessGroup: options.accessGroup,
        accessibility: .afterFirstUnlockThisDeviceOnly
      )
    )
  }

  static func makeTelemetryCollector() -> TelemetryCollector {
    TelemetryCollector()
  }

  static func makeAuthEventEmitter() -> EventEmitter<AuthEvent> {
    EventEmitter<AuthEvent>()
  }
}
