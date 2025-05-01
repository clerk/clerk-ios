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
    [firstName, lastName]
      .compactMap(\.self)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var intials: String? {
    [firstName ?? "", lastName ?? ""]
      .compactMap(\.self)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var identifier: String {
    if let username {
      return username
    }
    
    if let primaryEmailAddress {
      return primaryEmailAddress.emailAddress
    }
    
    if let primaryPhoneNumber {
      return primaryPhoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible
    }
    
    return ""
  }
  
}

#endif
