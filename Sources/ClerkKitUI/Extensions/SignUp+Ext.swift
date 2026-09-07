//
//  SignUp+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension SignUp {
  static let fieldPriority: [SignUp.Field] = [.emailAddress, .phoneNumber, .username, .password]
  static let individuallyCollectableFields: Set<SignUp.Field> = [.emailAddress, .phoneNumber, .username, .password]
  static let completeProfileFields: Set<SignUp.Field> = [.firstName, .lastName, .legalAccepted]

  var emailVerification: Verification? {
    verificationByAttribute["email_address"] ?? nil
  }

  func emailVerificationStrategy(prefersEmailLink: Bool) -> FactorStrategy {
    if let strategy = emailVerification?.factorStrategy {
      return strategy
    }

    return prefersEmailLink ? .emailLink : .emailCode
  }

  var firstFieldToCollect: SignUp.Field? {
    missing.sortedByPriority(SignUp.fieldPriority).first
  }

  var firstFieldToVerify: SignUp.Field? {
    unverified.sortedByPriority(SignUp.fieldPriority).first
  }

  func fieldIsRequired(field: SignUp.Field) -> Bool {
    required.contains(field)
  }

  var firstVerification: Verification? {
    guard let firstFieldToVerify else { return nil }
    return verificationByAttribute[firstFieldToVerify.rawValue] ?? nil
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
    return missing.allSatisfy { allSupportedFields.contains($0) }
  }
}

#endif
