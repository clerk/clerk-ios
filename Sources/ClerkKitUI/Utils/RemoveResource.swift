//
//  RemoveResource.swift
//  Clerk
//
//  Created by Mike Pitre on 5/27/25.
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

enum RemoveResource: Hashable {
  case email(EmailAddress)
  case phoneNumber(PhoneNumber)
  case externalAccount(ExternalAccount)
  case passkey(Passkey)
  case totp
  case secondFactorPhoneNumber(PhoneNumber)

  var title: LocalizedStringKey {
    switch self {
    case .email:
      "Remove email address"
    case .phoneNumber:
      "Remove phone number"
    case .externalAccount:
      "Remove connected account"
    case .passkey:
      "Remove passkey"
    case .totp, .secondFactorPhoneNumber:
      "Remove two-step verification"
    }
  }

  @MainActor
  var messageLine1: LocalizedStringKey {
    switch self {
    case let .email(emailAddress):
      "\(emailAddress.emailAddress) will be removed from this account. You will no longer be able to sign in using this email address."
    case let .phoneNumber(phoneNumber):
      "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will be removed from this account. You will no longer be able to sign in using this phone number."
    case let .externalAccount(externalAccount):
      "\(externalAccount.oauthProvider.name) will be removed from this account. You will no longer be able to sign in using this connected account."
    case let .passkey(passkey):
      "\(passkey.name) will be removed from this account. You will no longer be able to sign in using this passkey."
    case .totp:
      "Verification codes from this authenticator will no longer be required when signing in."
    case let .secondFactorPhoneNumber(phoneNumber):
      "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will no longer be receiving verification codes when signing in."
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
