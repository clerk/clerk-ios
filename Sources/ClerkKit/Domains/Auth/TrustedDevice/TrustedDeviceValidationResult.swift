//
//  TrustedDeviceValidationResult.swift
//  Clerk
//

import Foundation

package enum TrustedDeviceValidationResult: Equatable {
  case valid
  case invalid(TrustedDeviceAvailability.UnavailableReason)
  case inconclusive
}
