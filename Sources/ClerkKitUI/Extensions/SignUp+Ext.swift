//
//  SignUp+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import Foundation

extension SignUp {
  static let fieldPriority: [SignUpField] = [.emailAddress, .phoneNumber, .username, .password]
  static let individuallyCollectableFields: Set<SignUpField> = [.emailAddress, .phoneNumber, .username, .password]
  static let completeProfileFields: Set<SignUpField> = [.firstName, .lastName, .legalAccepted]

  var emailVerification: SignUpVerification? {
    verifications.emailAddress
  }

  @MainActor
  var emailVerificationStrategy: FactorStrategy {
    if let strategy = emailVerification?.strategy {
      return FactorStrategy(rawValue: strategy)
    }

    if let verifications = coreOwner?.environment.userSettings.attributes["email_address"]?.verifications,
       verifications.contains(.emailLink)
    {
      return .emailLink
    }

    return .emailCode
  }

  var firstFieldToCollect: SignUpField? {
    missingFields.sortedByPriority(SignUp.fieldPriority).first
  }

  var firstFieldToVerify: SignUpField? {
    unverifiedFields.map { SignUpField(rawValue: $0.rawValue) }.sortedByPriority(SignUp.fieldPriority).first
  }

  func fieldIsRequired(field: SignUpField) -> Bool {
    requiredFields.contains(field)
  }

  var firstVerification: SignUpVerification? {
    guard let firstFieldToVerify else { return nil }
    switch firstFieldToVerify {
    case .emailAddress: return verifications.emailAddress
    case .phoneNumber: return verifications.phoneNumber
    default: return nil
    }
  }

  func fieldWasCollected(field: SignUpField) -> Bool {
    switch field {
    case .emailAddress:
      emailAddress != nil
    case .phoneNumber:
      phoneNumber != nil
    case .username:
      username != nil
    case .password:
      hasPassword
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
