//
//  RemoveResource.swift
//  Clerk
//
//  Created by Mike Pitre on 5/27/25.
//

#if os(iOS)

  import Foundation
  import SwiftUI

  enum RemoveResource: Hashable {
    case email(EmailAddress)
    case phoneNumber(PhoneNumber)
    case externalAccount(ExternalAccount)
    case passkey(Passkey)

    var title: LocalizedStringKey {
      switch self {
      case .email:
        return "Remove email address"
      case .phoneNumber:
        return "Remove phone number"
      case .externalAccount:
        return "Remove connected account"
      case .passkey:
        return "Remove passkey"
      }
    }

    @MainActor
    var messageLine1: LocalizedStringKey {
      switch self {
      case .email(let emailAddress):
        return "\(emailAddress.emailAddress) will be removed from this account. You will no longer be able to sign in using this email address."
      case .phoneNumber(let phoneNumber):
        return "\(phoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible) will be removed from this account. You will no longer be able to sign in using this phone number."
      case .externalAccount(let externalAccount):
        return "\(externalAccount.oauthProvider.name) will be removed from this account. You will no longer be able to sign in using this connected account."
      case .passkey(let passkey):
        return "\(passkey.name) will be removed from this account. You will no longer be able to sign in using this passkey."
      }
    }

    func deleteAction() async throws {
      switch self {
      case .email(let emailAddress):
        try await emailAddress.destroy()
      case .phoneNumber(let phoneNumber):
        try await phoneNumber.delete()
      case .externalAccount(let externalAccount):
        try await externalAccount.destroy()
      case .passkey(let passkey):
        try await passkey.delete()
      }
    }
  }

#endif
