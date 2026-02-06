//
//  JSONEncoder+Ext.swift
//

import Foundation

extension JSONEncoder {
  static let clerkEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .millisecondsSince1970
    return encoder
  }()
}
