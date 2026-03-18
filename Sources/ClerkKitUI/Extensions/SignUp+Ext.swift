//
//  SignUp+Ext.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import Foundation

extension SignUp {
  static let fieldPriority: [SignUp.Field] = [.emailAddress, .phoneNumber, .username, .password]
  static let individuallyCollectableFields: Set<SignUp.Field> = [.emailAddress, .phoneNumber, .username, .password]
  static let completeProfileFields: Set<SignUp.Field> = [.firstName, .lastName, .legalAccepted]

  @MainActor
  var emailVerificationStrategy: FactorStrategy {
    // Check if there's an active verification with a strategy
    if let verification = verifications["email_address"],
       let strategy = verification?.strategy
    {
      return strategy
    }

    // Fall back to environment user settings
    if let verifications = Clerk.shared.environment?.userSettings.attributes["email_address"]?.verifications,
       verifications.contains("email_link")
    {
      return .emailLink
    }

    return .emailCode
  }

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
