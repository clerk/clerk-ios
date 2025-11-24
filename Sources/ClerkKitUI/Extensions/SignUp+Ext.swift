//
//  SignUp+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 6/20/25.
//

#if os(iOS)

import ClerkKit
import Foundation

extension SignUp {
  static let fieldPriority: [String] = ["email_address", "phone_number", "username", "password"]
  static let individuallyCollectableFields = ["email_address", "phone_number", "username", "password"]
  static let completeProfileFields = ["first_name", "last_name", "legal_accepted"]

  var firstFieldToCollect: String? {
    missingFields.sortedByPriority(SignUp.fieldPriority).first
  }

  var firstFieldToVerify: String? {
    unverifiedFields.sortedByPriority(SignUp.fieldPriority).first
  }

  func fieldIsRequired(field: String) -> Bool {
    requiredFields.contains(field)
  }

  var firstVerification: Verification? {
    verifications.first(where: { $0.key == firstFieldToVerify })?.value
  }

  func fieldWasCollected(field: String) -> Bool {
    switch field {
    case "email_address":
      emailAddress != nil
    case "phone_number":
      phoneNumber != nil
    case "username":
      username != nil
    case "password":
      passwordEnabled
    case "first_name":
      firstName != nil
    case "last_name":
      lastName != nil
    default:
      false
    }
  }

  var canCompleteProfileHandleMissingFields: Bool {
    let allSupportedFields = Set(SignUp.individuallyCollectableFields + SignUp.completeProfileFields)
    return missingFields.allSatisfy { allSupportedFields.contains($0) }
  }
}

#endif
