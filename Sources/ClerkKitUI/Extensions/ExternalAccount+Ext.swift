//
//  ExternalAccount+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

import ClerkKit
import Foundation

extension ExternalAccount {

  var oauthProvider: OAuthProvider {
    .init(strategy: provider)
  }

  var displayName: String {
    if let username, !username.isEmptyTrimmed {
      return username
    } else {
      return emailAddress
    }
  }

  var fullName: String? {
    let fullName = [firstName, lastName]
      .compactMap(\.self)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return fullName.isEmptyTrimmed ? nil : fullName
  }

}
