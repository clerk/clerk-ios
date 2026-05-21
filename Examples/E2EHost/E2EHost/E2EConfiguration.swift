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
  let cleanupOnLaunch: Bool

  init(
    publishableKey: String,
    authMode: AuthView.Mode,
    keychainService: String?,
    cleanupOnLaunch: Bool
  ) {
    self.publishableKey = publishableKey
    self.authMode = authMode
    self.keychainService = keychainService
    self.cleanupOnLaunch = cleanupOnLaunch
  }

  init(processInfo: ProcessInfo = .processInfo) {
    let environment = processInfo.environment

    publishableKey = Self.normalized(environment["CLERK_PUBLISHABLE_KEY"])
      ?? Self.normalized(environment["CLERK_E2E_PUBLISHABLE_KEY"])
      ?? ""
    authMode = Self.authMode(from: environment["CLERK_E2E_AUTH_MODE"])
    keychainService = Self.normalized(environment["CLERK_E2E_KEYCHAIN_SERVICE"])
    cleanupOnLaunch = environment["CLERK_E2E_CLEANUP_ON_LAUNCH"] == "1"
  }

  var clerkOptions: Clerk.Options {
    guard let keychainService else {
      return Clerk.Options()
    }

    return Clerk.Options(
      keychainConfig: .init(service: keychainService)
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
    keychainService: nil,
    cleanupOnLaunch: false
  )
}
