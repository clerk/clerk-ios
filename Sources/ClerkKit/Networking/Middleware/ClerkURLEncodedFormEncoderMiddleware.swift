//
//  ClerkURLEncodedFormEncoderMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 7/25/25.
//

import Foundation

struct ClerkURLEncodedFormEncoderMiddleware: NetworkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
  guard let data = request.httpBody else { return }
  let json = try? JSONDecoder.clerkDecoder.decode(JSON.self, from: data)
  request.httpBody = try? URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
  }
}
