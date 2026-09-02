//
//  BillingUnknownString.swift
//  Clerk
//

import Foundation

enum BillingUnknownString {
  static func decode(from decoder: Decoder) throws -> String {
    let container = try decoder.singleValueContainer()
    return try container.decode(String.self)
  }

  static func encode(_ rawValue: String, to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
