//
//  User+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension User {
  var identifier: String? {
    if let username, !username.isEmptyTrimmed {
      return username
    }

    if let primaryEmailAddress, !primaryEmailAddress.emailAddress.isEmptyTrimmed {
      return primaryEmailAddress.emailAddress
    }

    if let primaryPhoneNumber, !primaryPhoneNumber.phoneNumber.isEmptyTrimmed {
      return primaryPhoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible
    }

    return nil
  }

  var biometricCredentialIdentifierHint: String? {
    if let primaryEmailAddress, !primaryEmailAddress.emailAddress.isEmptyTrimmed {
      return primaryEmailAddress.emailAddress
    }

    if let primaryPhoneNumber, !primaryPhoneNumber.phoneNumber.isEmptyTrimmed {
      return primaryPhoneNumber.phoneNumber
    }

    if let username, !username.isEmptyTrimmed {
      return username
    }

    return nil
  }

  @MainActor
  var usernameForPasswordKeeper: String {
    guard let environment = Clerk.shared.environment else { return "" }
    let userSettings = environment.userSettings

    if userSettings.attributes.username.enabled, userSettings.attributes.username.usedForFirstFactor,
       let username
    {
      return username
    }

    if userSettings.attributes.emailAddress.enabled, userSettings.attributes.emailAddress.usedForFirstFactor,
       let email = primaryEmailAddress?.emailAddress
    {
      return email
    }

    if userSettings.attributes.phoneNumber.enabled, userSettings.attributes.phoneNumber.usedForFirstFactor,
       let phone = primaryPhoneNumber?.phoneNumber
    {
      return phone
    }

    return ""
  }

  @MainActor
  var unconnectedProviders: [OAuthProvider] {
    guard let environment = Clerk.shared.environment else { return [] }
    let socialProviders = environment.enabledOAuthProviders
    let verifiedExternalProviders = verifiedExternalAccounts.compactMap { $0.oauthProvider }
    return socialProviders.filter { !verifiedExternalProviders.contains($0) }
  }

  var phoneNumbersAvailableForMfa: [PhoneNumber] {
    phoneNumbers.filter { !$0.reservedForSecondFactor }
  }

  var phoneNumbersReservedForMfa: [PhoneNumber] {
    phoneNumbers.filter { $0.verification?.status == .verified && $0.reservedForSecondFactor }
  }
}

#endif
