//
//  SignUp+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 6/20/25.
//

#if os(iOS)

  import Foundation

  extension SignUp {

    var individuallyCollectableFields: [String] {
      ["email_address", "phone_number", "username", "password"].sorted { lhs, rhs in
        let lhsRequired = fieldIsRequired(field: lhs)
        let rhsRequired = fieldIsRequired(field: rhs)

        // Non-required fields come first
        if !lhsRequired && rhsRequired {
          return true
        } else if lhsRequired && !rhsRequired {
          return false
        } else {
          // If both are required or both are optional, maintain original order
          return false
        }
      }
    }

    var firstFieldToCollect: String? {
      missingFields.first
    }

    var firstFieldToVerify: String? {
      unverifiedFields.first
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
        return emailAddress != nil
      case "phone_number":
        return phoneNumber != nil
      case "username":
        return username != nil
      case "password":
        return passwordEnabled
      default:
        return false
      }
    }

  }

#endif
