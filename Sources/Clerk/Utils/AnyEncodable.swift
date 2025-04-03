//
//  AnyEncodable.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Foundation

struct AnyEncodable: Encodable {
  let value: Encodable

  init<T: Encodable>(_ value: T) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    try value.encode(to: encoder)
  }
}
