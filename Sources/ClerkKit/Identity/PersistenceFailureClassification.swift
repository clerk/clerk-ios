//
//  PersistenceFailureClassification.swift
//  Clerk
//

import Foundation
import Security

extension PersistenceFailureKind {
  static func classify(_ error: any Error) -> Self {
    if error is DecodingError {
      return .incompatibleStoredData
    }
    if error is AppLocalKeychainMigrationError {
      return .incompatibleStoredData
    }
    if error is AppContainerIdentityClearIntentError {
      return .incompatibleStoredData
    }

    guard let keychainError = error as? KeychainError else {
      if error is SharedSessionLocalIdentityStoreError {
        return .incompatibleStoredData
      }
      if error is SharedSessionOwnerSlotClearRecoveryError {
        return .incompatibleStoredData
      }
      return .unexpected
    }

    switch keychainError {
    case .unexpectedStatus(errSecMissingEntitlement):
      return .missingEntitlement
    case .unexpectedStatus(errSecNotAvailable),
         .unexpectedStatus(errSecInteractionNotAllowed):
      return .temporarilyUnavailable
    case .unexpectedStatus:
      return .unexpected
    case .invalidStringEncoding:
      return .incompatibleStoredData
    }
  }

  var permitsVolatileIdentityFallback: Bool {
    switch self {
    case .temporarilyUnavailable, .missingEntitlement:
      true
    case .incompatibleStoredData, .unexpected:
      false
    }
  }
}
