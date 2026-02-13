//
//  AppVersionComparator.swift
//  Clerk
//

import Foundation

enum AppVersionComparator {
  static func isValid(_ version: String) -> Bool {
    version.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
  }

  static func parse(_ version: String) -> [Int]? {
    guard isValid(version) else { return nil }
    return version
      .split(separator: ".")
      .compactMap { Int($0) }
  }

  /// Returns a positive value when `lhs > rhs`, 0 for equality and a negative value when `lhs < rhs`.
  static func compare(_ lhs: String, _ rhs: String) -> Int? {
    guard let lhsSegments = parse(lhs), let rhsSegments = parse(rhs) else {
      return nil
    }

    let maxCount = Swift.max(lhsSegments.count, rhsSegments.count)
    for index in 0 ..< maxCount {
      let lhsValue = index < lhsSegments.count ? lhsSegments[index] : 0
      let rhsValue = index < rhsSegments.count ? rhsSegments[index] : 0

      if lhsValue != rhsValue {
        return lhsValue - rhsValue
      }
    }

    return 0
  }

  static func isSupported(current: String, minimum: String) -> Bool? {
    guard let comparison = compare(current, minimum) else {
      return nil
    }
    return comparison >= 0
  }
}
