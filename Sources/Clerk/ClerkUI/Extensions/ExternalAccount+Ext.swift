//
//  ExternalAccount+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 5/9/25.
//

import Foundation

extension ExternalAccount {

  var oauthProvider: OAuthProvider {
    .init(strategy: provider)
  }

  var displayName: String {
    if let username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
    
    return fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fullName
  }

}
