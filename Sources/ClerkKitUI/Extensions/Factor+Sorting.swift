//
//  Factor+Sorting.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

#if os(iOS)

import Foundation

public extension Factor {
  private static let strategySortOrderPasswordPref = [
    "passkey",
    "password",
    "email_code",
    "phone_code",
  ]

  private static let strategySortOrderOtpPref = [
    "email_code",
    "phone_code",
    "passkey",
    "password",
  ]

  private static let strategySortOrderAllStrategies = [
    "email_code",
    "phone_code",
    "passkey",
    "password",
  ]

  private static let strategySortOrderBackupCodePref = [
    "totp",
    "phone_code",
    "backup_code",
  ]

  struct PasswordPrefComparator: SortComparator {
    public typealias Compared = Factor
    public var order: SortOrder = .forward

    public func compare(_ lhs: Factor, _ rhs: Factor) -> ComparisonResult {
      guard let order1 = strategySortOrderPasswordPref.firstIndex(of: lhs.strategy),
            let order2 = strategySortOrderPasswordPref.firstIndex(of: rhs.strategy)
      else {
        return .orderedSame
      }
      return order1 < order2 ? .orderedAscending : .orderedDescending
    }
  }

  struct OtpPrefComparator: SortComparator {
    public typealias Compared = Factor
    public var order: SortOrder = .forward

    public func compare(_ lhs: Factor, _ rhs: Factor) -> ComparisonResult {
      guard let order1 = strategySortOrderOtpPref.firstIndex(of: lhs.strategy),
            let order2 = strategySortOrderOtpPref.firstIndex(of: rhs.strategy)
      else {
        return .orderedSame
      }
      return order1 < order2 ? .orderedAscending : .orderedDescending
    }
  }

  struct BackupCodePrefComparator: SortComparator {
    public typealias Compared = Factor
    public var order: SortOrder = .forward

    public func compare(_ lhs: Factor, _ rhs: Factor) -> ComparisonResult {
      guard let order1 = strategySortOrderBackupCodePref.firstIndex(of: lhs.strategy),
            let order2 = strategySortOrderBackupCodePref.firstIndex(of: rhs.strategy)
      else {
        return .orderedSame
      }
      return order1 < order2 ? .orderedAscending : .orderedDescending
    }
  }

  struct AllStrategiesButtonsComparator: SortComparator {
    public typealias Compared = Factor
    public var order: SortOrder = .forward

    public func compare(_ lhs: Factor, _ rhs: Factor) -> ComparisonResult {
      guard let order1 = strategySortOrderAllStrategies.firstIndex(of: lhs.strategy),
            let order2 = strategySortOrderAllStrategies.firstIndex(of: rhs.strategy)
      else {
        return .orderedSame
      }
      return order1 < order2 ? .orderedAscending : .orderedDescending
    }
  }

  static let passwordPrefComparator = PasswordPrefComparator()
  static let otpPrefComparator = OtpPrefComparator()
  static let backupCodePrefComparator = BackupCodePrefComparator()
  static let allStrategiesButtonsComparator = AllStrategiesButtonsComparator()
}

#endif
