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
    
    return fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fullName
  }
  
  var intials: String? {
    let initials = [firstName ?? "", lastName ?? ""]
      .compactMap(\.self)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    
    return initials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : initials
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
