//
//  BiometricCredentialValidationResult.swift
//  Clerk
//

import Foundation

package enum BiometricCredentialValidationResult: Equatable {
  case valid
  case invalid(BiometricCredentialAvailability.UnavailableReason)
  case inconclusive
}
