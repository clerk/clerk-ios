//
//  RemoveResource.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation
import SwiftUI

enum RemoveResource: Equatable {
  case email(EmailAddress)
  case phoneNumber(PhoneNumber)
  case externalAccount(ExternalAccount)
  case passkey(Passkey)
  case totp
  case secondFactorPhoneNumber(PhoneNumber)

  func title(locale: Locale) -> String {
    switch self {
    case .email:
      String(localized: "Remove email address", bundle: .module, locale: locale)
    case .phoneNumber:
      String(localized: "Remove phone number", bundle: .module, locale: locale)
    case .externalAccount:
      String(localized: "Remove connected account", bundle: .module, locale: locale)
    case .passkey:
      String(localized: "Remove passkey", bundle: .module, locale: locale)
    case .totp, .secondFactorPhoneNumber:
      String(localized: "Remove two-step verification", bundle: .module, locale: locale)
    }
  }

  @MainActor
  func messageLine1(locale: Locale) -> String {
    switch self {
    case let .email(emailAddress):
      String(localized: "\(emailAddress.emailAddress) will be removed from this account. You will no longer be able to sign in using this email address.", bundle: .module, locale: locale)
    case let .phoneNumber(phoneNumber):
      String(localized: "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will be removed from this account. You will no longer be able to sign in using this phone number.", bundle: .module, locale: locale)
    case let .externalAccount(externalAccount):
      String(localized: "\(externalAccount.oauthProvider.name) will be removed from this account. You will no longer be able to sign in using this connected account.", bundle: .module, locale: locale)
    case let .passkey(passkey):
      String(localized: "\(passkey.name) will be removed from this account. You will no longer be able to sign in using this passkey.", bundle: .module, locale: locale)
    case .totp:
      String(localized: "Verification codes from this authenticator will no longer be required when signing in.", bundle: .module, locale: locale)
    case let .secondFactorPhoneNumber(phoneNumber):
      String(localized: "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will no longer be receiving verification codes when signing in.", bundle: .module, locale: locale)
    }
  }

  func deleteAction() async throws {
    switch self {
    case let .email(emailAddress):
      try await emailAddress.destroy()
    case let .phoneNumber(phoneNumber):
      try await phoneNumber.delete()
    case let .externalAccount(externalAccount):
      try await externalAccount.destroy()
    case let .passkey(passkey):
      try await passkey.delete()
    case .totp:
      try await Clerk.shared.user?.disableTOTP()
    case let .secondFactorPhoneNumber(phoneNumber):
      try await phoneNumber.setReservedForSecondFactor(reserved: false)
    }
  }
}

#endif
