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
      String(localizedInClerkUI: "Remove email address", locale: locale)
    case .phoneNumber:
      String(localizedInClerkUI: "Remove phone number", locale: locale)
    case .externalAccount:
      String(localizedInClerkUI: "Remove connected account", locale: locale)
    case .passkey:
      String(localizedInClerkUI: "Remove passkey", locale: locale)
    case .totp, .secondFactorPhoneNumber:
      String(localizedInClerkUI: "Remove two-step verification", locale: locale)
    }
  }

  @MainActor
  func messageLine1(locale: Locale) -> String {
    switch self {
    case let .email(emailAddress):
      String(localizedInClerkUI: "\(emailAddress.emailAddress) will be removed from this account. You will no longer be able to sign in using this email address.", locale: locale)
    case let .phoneNumber(phoneNumber):
      String(localizedInClerkUI: "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will be removed from this account. You will no longer be able to sign in using this phone number.", locale: locale)
    case let .externalAccount(externalAccount):
      String(localizedInClerkUI: "\(externalAccount.oauthProvider.name) will be removed from this account. You will no longer be able to sign in using this connected account.", locale: locale)
    case let .passkey(passkey):
      String(localizedInClerkUI: "\(passkey.name) will be removed from this account. You will no longer be able to sign in using this passkey.", locale: locale)
    case .totp:
      String(localizedInClerkUI: "Verification codes from this authenticator will no longer be required when signing in.", locale: locale)
    case let .secondFactorPhoneNumber(phoneNumber):
      String(localizedInClerkUI: "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will no longer be receiving verification codes when signing in.", locale: locale)
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
