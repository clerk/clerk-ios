//
//  ClerkURLEncodedFormEncoderMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkURLEncodedFormEncoderMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    let contentType = request.value(forHTTPHeaderField: "Content-Type")?.lowercased()
    guard contentType?.contains("application/x-www-form-urlencoded") == true else { return }
    guard let data = request.httpBody else { return }

    // Form endpoints reject bracket-encoded nested params (e.g. unsafe_metadata[key]=value),
    // so nested top-level values are stringified as JSON before form serialization.
    var json = try JSONDecoder.clerkDecoder.decode(JSON.self, from: data)

    if case .object(var dict) = json {
      for (key, value) in dict {
        switch value {
        case .object, .array:
          let nestedData = try JSONEncoder().encode(value)
          dict[key] = .string(String(decoding: nestedData, as: UTF8.self))
        default:
          continue
        }
      }
      json = .object(dict)
    }

    request.httpBody = try URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
  }
}
