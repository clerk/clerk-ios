import Foundation
import Get
import SimpleKeychain

#if os(iOS)
import PhoneNumberKit
#endif

/// Minimal dependency container owned by `Clerk`. This mirrors Superwall's
/// approach of a central object that wires up shared utilities.
final class DependencyContainer {
  private let apiClientDelegate: ClerkAPIClientDelegate

  private(set) var settings: Clerk.Settings
  private(set) var keychain: KeychainStore
  private(set) var apiClient: APIClient

  #if os(iOS)
  lazy var phoneNumberUtility = PhoneNumberUtility()
  #endif

  init(
    settings: Clerk.Settings = .init(),
    frontendAPIURL: URL? = nil,
    apiClient: APIClient? = nil,
    keychain: KeychainStore? = nil,
    apiClientDelegate: ClerkAPIClientDelegate = ClerkAPIClientDelegate()
  ) {
    self.settings = settings
    self.apiClientDelegate = apiClientDelegate
    self.keychain = keychain ?? DependencyContainer.makeKeychain(config: settings.keychainConfig)
    self.apiClient = apiClient ?? DependencyContainer.makeApiClient(
      baseURL: frontendAPIURL,
      delegate: apiClientDelegate
    )
  }

  func updateSettings(_ settings: Clerk.Settings, keychain: KeychainStore? = nil) {
    self.settings = settings
    self.keychain = keychain ?? DependencyContainer.makeKeychain(config: settings.keychainConfig)
  }

  func updateFrontendAPIURL(_ frontendApiUrl: String) {
    let baseURL = URL(string: frontendApiUrl)
    self.apiClient = DependencyContainer.makeApiClient(
      baseURL: baseURL,
      delegate: apiClientDelegate
    )
  }

  func overrideApiClient(_ client: APIClient) {
    self.apiClient = client
  }

  func overrideKeychain(_ keychain: KeychainStore) {
    self.keychain = keychain
  }
}

// MARK: - Helpers
private extension DependencyContainer {
  static func makeApiClient(
    baseURL: URL?,
    delegate: ClerkAPIClientDelegate
  ) -> APIClient {
    APIClient(baseURL: baseURL) { configuration in
      configuration.delegate = delegate
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": "2025-04-10",
        "x-ios-sdk-version": Clerk.version,
        "x-mobile": "1"
      ]
    }
  }

  static func makeKeychain(config: KeychainConfig) -> KeychainStore {
    DefaultKeychain(simpleKeychain: SimpleKeychain(
      service: config.service,
      accessGroup: config.accessGroup,
      accessibility: .afterFirstUnlockThisDeviceOnly
    ))
  }
}
