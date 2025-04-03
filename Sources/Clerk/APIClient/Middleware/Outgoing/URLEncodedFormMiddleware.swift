//
//  URLEncodedFormMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct URLEncodedFormMiddleware {

  static func process(_ request: inout URLRequest) throws {
    // Encode body with url-encoded form
    if let data = request.httpBody {
      let json = try JSONDecoder.clerkDecoder.decode(JSON.self, from: data)
      request.httpBody = try URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
    }
  }

}
