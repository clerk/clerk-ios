//
//  User+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

  import Foundation

  extension User {

    var fullName: String? {
      let fullName = [firstName, lastName]
        .compactMap(\.self)
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      return fullName.isEmptyTrimmed ? nil : fullName
    }

    var intials: String? {
      let initials = [firstName ?? "", lastName ?? ""]
        .compactMap(\.self)
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      return initials.isEmptyTrimmed ? nil : initials
    }

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

    @MainActor
    var usernameForPasswordKeeper: String {
      guard let userSettings = Clerk.shared.environment.userSettings else { return "" }

      if userSettings.attributes.contains(where: { $0 == "username" && $1.enabled && $1.usedForFirstFactor }),
        let username
      {
        return username
      }

      if userSettings.attributes.contains(where: { $0 == "email_address" && $1.enabled && $1.usedForFirstFactor }),
        let email = primaryEmailAddress?.emailAddress
      {
        return email
      }

      if userSettings.attributes.contains(where: { $0 == "phone_number" && $1.enabled && $1.usedForFirstFactor }),
        let phone = primaryPhoneNumber?.phoneNumber
      {
        return phone
      }

      return ""
    }

    @MainActor
    var unconnectedProviders: [OAuthProvider] {
      let socialProviders = Clerk.shared.environment.allSocialProviders
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
