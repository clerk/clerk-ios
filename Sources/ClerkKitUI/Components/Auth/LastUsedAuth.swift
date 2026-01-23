//
//  LastUsedAuth.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import ClerkKit
import Foundation

@MainActor
enum LastUsedAuth: Equatable {
  case email
  case username
  case phone
  case social(OAuthProvider)

  init?(environment: Clerk.Environment?) {
    guard let lastAuth = Clerk.shared.client?.lastAuthenticationStrategy,
          (environment?.totalEnabledFirstFactorMethods ?? 0) > 1
    else {
      return nil
    }

    let providers = environment?.authenticatableSocialProviders ?? []
    if let provider = providers.first(where: {
      Self.shouldShowBadge(for: [.oauth($0)], lastAuth: lastAuth, environment: environment)
    }) {
      self = .social(provider)
      return
    }

    if Self.shouldShowBadge(for: FactorStrategy.phoneStrategies, lastAuth: lastAuth, environment: environment) {
      self = .phone
      return
    }

    if Self.shouldShowBadge(for: FactorStrategy.emailStrategies, lastAuth: lastAuth, environment: environment) {
      self = .email
      return
    }

    if Self.shouldShowBadge(for: FactorStrategy.usernameStrategies, lastAuth: lastAuth, environment: environment) {
      self = .username
      return
    }

    return nil
  }

  var socialProvider: OAuthProvider? {
    switch self {
    case .social(let provider):
      provider
    case .email, .username, .phone:
      nil
    }
  }

  var showsEmailUsernameBadge: Bool {
    switch self {
    case .email, .username:
      true
    case .phone, .social:
      false
    }
  }

  var showsPhoneBadge: Bool {
    switch self {
    case .phone:
      true
    case .email, .username, .social:
      false
    }
  }

  static func storeIdentifierType(_ identifier: LastUsedAuth) {
    guard let rawValue = identifier.identifierStorageValue else { return }
    UserDefaults.standard.set(rawValue, forKey: identifierStorageKey)
  }

  static func retrieveStoredIdentifierType() -> LastUsedAuth? {
    guard let rawValue = UserDefaults.standard.string(forKey: identifierStorageKey) else {
      return nil
    }

    return switch rawValue {
    case "email":
      .email
    case "phone":
      .phone
    case "username":
      .username
    default:
      nil
    }
  }

  static func clearStoredIdentifierType() {
    UserDefaults.standard.removeObject(forKey: identifierStorageKey)
  }
}

extension Clerk.Environment {
  /// Total count of enabled authentication methods.
  ///
  /// This counts:
  /// - First factor identifiers (email, phone, username) that are enabled
  /// - Authenticatable OAuth providers
  ///
  /// Used to determine whether to show authentication badges (only shown when > 1 method is available).
  var totalEnabledFirstFactorMethods: Int {
    let identifierKeys: Set<String> = ["email_address", "phone_number", "username"]

    let firstFactorCount = userSettings.attributes
      .filter { key, value in
        identifierKeys.contains(key) &&
          value.enabled &&
          value.usedForFirstFactor
      }
      .count

    let oauthCount = authenticatableSocialProviders.count

    return firstFactorCount + oauthCount
  }

  /// Whether the last used authentication badge can be shown for identifier-based strategies
  /// based purely on the enabled identifier combinations.
  ///
  /// Returns `true` when the identifier type is unambiguous:
  /// - Email and/or username are enabled (without phone)
  /// - Only phone is enabled
  ///
  /// Returns `false` when phone is combined with email or username, since the backend
  /// cannot distinguish which identifier type was used. In this case, the badge can still
  /// be shown if `LastUsedAuth` has a stored identifier type to disambiguate.
  var canShowLastUsedBadge: Bool {
    let hasEmail = userSettings.attributes.contains { key, value in
      key == "email_address" && value.enabled && value.usedForFirstFactor
    }
    let hasPhone = userSettings.attributes.contains { key, value in
      key == "phone_number" && value.enabled && value.usedForFirstFactor
    }
    let hasUsername = userSettings.attributes.contains { key, value in
      key == "username" && value.enabled && value.usedForFirstFactor
    }

    if hasPhone, hasEmail || hasUsername {
      return false
    }

    return true
  }
}

private extension LastUsedAuth {
  static let identifierStorageKey = "clerk_last_used_identifier_type"

  static func shouldShowBadge(
    for strategies: [FactorStrategy],
    lastAuth: FactorStrategy,
    environment: Clerk.Environment?
  ) -> Bool {
    if lastAuth == .password, let storedIdentifier = retrieveStoredIdentifierType() {
      return storedIdentifier.matches(strategies)
    }

    let identifierStrategies = FactorStrategy.emailStrategies
      + FactorStrategy.phoneStrategies
      + FactorStrategy.usernameStrategies

    if identifierStrategies.contains(lastAuth), !(environment?.canShowLastUsedBadge ?? false) {
      return false
    }

    return strategies.contains(lastAuth)
  }

  func matches(_ strategies: [FactorStrategy]) -> Bool {
    switch self {
    case .email:
      strategies.contains(.emailCode)
    case .phone:
      strategies.contains(.phoneCode)
    case .username:
      strategies.contains(.password)
        && Set(strategies).isDisjoint(with: [.emailCode, .phoneCode])
    case .social:
      false
    }
  }

  var identifierStorageValue: String? {
    switch self {
    case .email:
      "email"
    case .phone:
      "phone"
    case .username:
      "username"
    case .social:
      nil
    }
  }
}

#endif
