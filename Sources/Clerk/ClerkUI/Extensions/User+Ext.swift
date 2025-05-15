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
  
  var identifier: String? {        
    if let username, !username.isEmpty {
      return username
    }
    
    if let primaryEmailAddress, !primaryEmailAddress.emailAddress.isEmpty {
      return primaryEmailAddress.emailAddress
    }
    
    if let primaryPhoneNumber, !primaryPhoneNumber.phoneNumber.isEmpty {
      return primaryPhoneNumber.phoneNumber.formattedAsPhoneNumberIfPossible
    }
    
    return nil
  }
  
}

#endif
