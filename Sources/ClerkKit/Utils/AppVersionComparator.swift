//
//  AppVersionComparator.swift
//  Clerk
//

import Foundation

enum AppVersionComparator {
  static func isValid(_ version: String) -> Bool {
    version.range(of: #"^\d+(?:\.\d+){0,2}$"#, options: .regularExpression) != nil
  }

  static func parse(_ version: String) -> [Int]? {
    guard isValid(version) else { return nil }
    let segments = version.split(separator: ".")
    let values = segments.compactMap { Int($0) }
    return values.count == segments.count ? values : nil
  }

  static func compare(_ lhs: String, _ rhs: String) -> Int? {
    guard let lhsSegments = parse(lhs), let rhsSegments = parse(rhs) else {
      return nil
    }

    for index in 0 ..< max(lhsSegments.count, rhsSegments.count) {
      let lhsValue = index < lhsSegments.count ? lhsSegments[index] : 0
      let rhsValue = index < rhsSegments.count ? rhsSegments[index] : 0
      if lhsValue < rhsValue { return -1 }
      if lhsValue > rhsValue { return 1 }
    }

    return 0
  }

  static func isSupported(current: String, minimum: String) -> Bool? {
    compare(current, minimum).map { $0 >= 0 }
  }
}
