//
//  E2EConfiguration.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import Foundation

struct E2EConfiguration {
  let publishableKey: String
  let authMode: AuthView.Mode
  let keychainService: String?

  init(
    publishableKey: String,
    authMode: AuthView.Mode,
    keychainService: String?
  ) {
    self.publishableKey = publishableKey
    self.authMode = authMode
    self.keychainService = keychainService
  }

  init(processInfo: ProcessInfo = .processInfo) {
    let environment = processInfo.environment

    publishableKey = Self.normalized(environment["CLERK_PUBLISHABLE_KEY"])
      ?? Self.normalized(environment["CLERK_E2E_PUBLISHABLE_KEY"])
      ?? ""
    authMode = Self.authMode(from: environment["CLERK_E2E_AUTH_MODE"])
    keychainService = Self.normalized(environment["CLERK_E2E_KEYCHAIN_SERVICE"])
  }

  @MainActor
  func connect(authentication: AppleAuthentication) async throws -> Clerk {
    let configuration = try ClerkConfiguration(
      publishableKey: publishableKey,
      callbackURL: URL(string: "com.clerk.E2EHost://oauth/callback")!,
      legacyKeychain: .init(service: keychainService, publishableKey: publishableKey)
    )
    let namespace = keychainService ?? Bundle.main.bundleIdentifier ?? "com.clerk.E2EHost"
    func storage(_ purpose: KeychainCredentialStorage.Purpose) -> KeychainCredentialStorage {
      KeychainCredentialStorage(
        publishableKey: publishableKey, frontendAPI: configuration.frontendAPI,
        applicationIdentifier: namespace, legacy: configuration.legacyKeychain, purpose: purpose
      )
    }
    return try await Clerk.connect(
      configuration: configuration, storage: storage(.client),
      browser: authentication.openBrowser, passkeys: authentication.credential,
      appleIdentity: authentication.appleIdentity, authStorage: storage(.magicLink),
      biometrics: AppleBiometricCapabilities(
        publishableKey: publishableKey, appIdentifier: namespace,
        credentials: storage(.biometricCredentials), cleanup: storage(.biometricCleanup)
      )
    )
  }

  private static func authMode(from value: String?) -> AuthView.Mode {
    guard let value = normalized(value), let authMode = AuthView.Mode(rawValue: value) else {
      return .signInOrUp
    }

    return authMode
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }

    return value
  }
}

extension E2EConfiguration {
  static let mock = E2EConfiguration(
    publishableKey: "",
    authMode: .signInOrUp,
    keychainService: nil
  )
}
