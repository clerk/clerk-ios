//
//  JSONEncoder+Ext.swift
//
//
//  Created by Mike Pitre on 12/11/23.
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
