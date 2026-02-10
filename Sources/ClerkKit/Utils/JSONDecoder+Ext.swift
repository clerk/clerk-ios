//
//  JSONDecoder+Ext.swift
//

import Foundation

extension JSONDecoder {
  static let clerkDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return decoder
  }()
}
