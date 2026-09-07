//
//  ExternalAccount+Ext.swift
//  Clerk
//

import ClerkKit
import Foundation

extension ExternalAccount {
  var oauthProvider: OAuthProvider {
    .init(strategy: provider)
  }

  var displayName: String {
    if !username.isEmptyTrimmed {
      username
    } else {
      emailAddress
    }
  }

  var fullName: String? {
    let fullName = [firstName, lastName]
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return fullName.isEmptyTrimmed ? nil : fullName
  }
}
