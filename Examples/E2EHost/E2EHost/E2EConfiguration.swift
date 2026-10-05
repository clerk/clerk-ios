//
//  E2EConfiguration.swift
//  E2EHost
//

import ClerkKit
import ClerkKitUI
import Foundation

enum VerifyScreen: String {
  case home
  case auth
  case userProfile
  case orgSwitcher
  case orgList
  case orgProfile
}

struct E2EConfiguration {
  let publishableKey: String
  let authMode: AuthView.Mode
  let keychainService: String?
  let runId: String?
  let launchId: String?
  let screen: VerifyScreen
  let screenFailure: VerifyState.Failure?
  let signInTicket: String?
  let logLevel: LogLevel

  init(
    publishableKey: String,
    authMode: AuthView.Mode,
    keychainService: String?
  ) {
    self.publishableKey = publishableKey
    self.authMode = authMode
    self.keychainService = keychainService
    runId = nil
    launchId = nil
    screen = .home
    screenFailure = nil
    signInTicket = nil
    logLevel = .error
  }

  init(processInfo: ProcessInfo = .processInfo, defaults: UserDefaults = .standard) {
    let environment = processInfo.environment
    let argument = { (key: String) in Self.normalized(defaults.string(forKey: key)) }

    publishableKey = argument("verifyPublishableKey")
      ?? Self.normalized(environment["CLERK_PUBLISHABLE_KEY"])
      ?? Self.normalized(environment["CLERK_E2E_PUBLISHABLE_KEY"])
      ?? ""
    authMode = Self.authMode(from: argument("verifyAuthMode") ?? environment["CLERK_E2E_AUTH_MODE"])
    keychainService = argument("verifyStorageScope").map { "verify.\($0)" }
      ?? Self.normalized(environment["CLERK_E2E_KEYCHAIN_SERVICE"])
    runId = argument("verifyRunId")
    launchId = argument("verifyLaunchId")
    let requestedScreen = argument("verifyScreen")
    screen = requestedScreen.flatMap(VerifyScreen.init(rawValue:)) ?? .home
    screenFailure = requestedScreen.flatMap { value in
      VerifyScreen(rawValue: value) == nil ? .init(code: "unknown-screen", message: value) : nil
    }
    signInTicket = argument("verifySignInTicket")
    logLevel = argument("verifyLogLevel") == "debug" ? .debug : .error
  }

  var clerkOptions: Clerk.Options {
    Clerk.Options(
      logLevel: logLevel,
      keychainConfig: keychainService.map { .init(service: $0) } ?? .init()
    )
  }

  var publishableKeyFailure: VerifyState.Failure? {
    let payload = ["pk_test_", "pk_live_"]
      .first { publishableKey.hasPrefix($0) }
      .map { publishableKey.dropFirst($0.count) }

    guard let payload, !payload.isEmpty, Self.decodesAsBase64URL(payload) else {
      return .init(
        code: "invalid_publishable_key",
        message: "The publishable key is missing or is not a pk_test_ or pk_live_ key."
      )
    }

    return nil
  }

  private static func decodesAsBase64URL(_ value: Substring) -> Bool {
    var base64 = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

    guard let data = Data(base64Encoded: base64) else {
      return false
    }

    return String(data: data, encoding: .utf8) != nil
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
