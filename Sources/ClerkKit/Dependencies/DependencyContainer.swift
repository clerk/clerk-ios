import Foundation

/// Central dependency container owned by `Clerk`.
final class DependencyContainer {
  var configManager: ConfigManager
  var keychain: KeychainStore
  var apiClient: any APIClientProtocol
  var telemetry: TelemetryCollector
  var authEventEmitter: EventEmitter<AuthEvent>
  var appLifecycleManager: AppLifecycleManager
  var persistedStateStore: PersistedStateStore
  var pendingSessionLogger: PendingSessionLogger
  var deviceAttestationCoordinator: DeviceAttestationCoordinator

  init(options: ClerkOptions? = nil) {
    let options = options ?? ClerkOptions()
    self.configManager = ConfigManager(options: options)
    self.keychain = DependencyContainer.makeKeychain(options: options.keychain)
    self.apiClient = DependencyContainer.makeApiClient(baseURL: configManager.frontendAPIURL)
    self.telemetry = TelemetryCollector()
    self.authEventEmitter = EventEmitter<AuthEvent>()

    self.appLifecycleManager = AppLifecycleManager(
      notificationCenter: .default,
      telemetry: telemetry
    )

    self.persistedStateStore = PersistedStateStore(keychain: keychain)
    self.pendingSessionLogger = PendingSessionLogger()
    self.deviceAttestationCoordinator = DeviceAttestationCoordinator()
  }

  func configure(publishableKey: String) {
    configManager.configure(publishableKey: publishableKey)
    apiClient = DependencyContainer.makeApiClient(baseURL: configManager.frontendAPIURL)
  }

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
}
