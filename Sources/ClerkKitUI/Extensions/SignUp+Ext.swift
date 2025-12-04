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
  static let fieldPriority: [SignUp.Field] = [.emailAddress, .phoneNumber, .username, .password]
  static let individuallyCollectableFields: Set<SignUp.Field> = [.emailAddress, .phoneNumber, .username, .password]
  static let completeProfileFields: Set<SignUp.Field> = [.firstName, .lastName, .legalAccepted]

  var firstFieldToCollect: SignUp.Field? {
    missingFields.sortedByPriority(SignUp.fieldPriority).first
  }

  var firstFieldToVerify: SignUp.Field? {
    unverifiedFields.sortedByPriority(SignUp.fieldPriority).first
  }

  func fieldIsRequired(field: SignUp.Field) -> Bool {
    requiredFields.contains(field)
  }

  var firstVerification: Verification? {
    guard let firstFieldToVerify else { return nil }
    return verifications.first(where: { $0.key == firstFieldToVerify.rawValue })?.value
  }

  func fieldWasCollected(field: SignUp.Field) -> Bool {
    switch field {
    case .emailAddress:
      emailAddress != nil
    case .phoneNumber:
      phoneNumber != nil
    case .username:
      username != nil
    case .password:
      passwordEnabled
    case .firstName:
      firstName != nil
    case .lastName:
      lastName != nil
    default:
      false
    }
  }

  var canCompleteProfileHandleMissingFields: Bool {
    let allSupportedFields = SignUp.individuallyCollectableFields.union(SignUp.completeProfileFields)
    return missingFields.allSatisfy { allSupportedFields.contains($0) }
  }
}

#endif
