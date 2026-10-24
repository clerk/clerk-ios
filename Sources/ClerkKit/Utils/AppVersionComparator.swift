//
//  AppVersionComparator.swift
//  Clerk
//

import Foundation

enum AppVersionComparator {
  static func isSupported(current: String, minimum: String) -> Bool? {
    guard let current = segments(current), let minimum = segments(minimum) else {
      return nil
    }
    return !current.lexicographicallyPrecedes(minimum)
  }

  private static func segments(_ version: String) -> [Int]? {
    guard version.range(of: #"^\d+(?:\.\d+){0,2}$"#, options: .regularExpression) != nil else {
      return nil
    }
    let parts = version.split(separator: ".")
    let values = parts.compactMap { Int($0) }
    guard values.count == parts.count else { return nil }
    return values + Array(repeating: 0, count: 3 - values.count)
  }
}
