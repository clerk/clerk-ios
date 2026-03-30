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
    // so nested values in the top-level object are stringified as JSON before form
    // serialization. String arrays are preserved as-is so the form encoder emits
    // repeated keys (e.g. additional_scope=write&additional_scope=view).
    var json = try JSONDecoder.clerkDecoder.decode(JSON.self, from: data)

    if case .object(var dict) = json {
      for (key, value) in dict {
        switch value {
        case .array(let elements) where elements.allSatisfy(\.isString):
          continue
        case .object, .array:
          let nestedData = try JSONEncoder().encode(value)
          guard let nestedString = String(bytes: nestedData, encoding: .utf8) else {
            continue
          }
          dict[key] = .string(nestedString)
        default:
          continue
        }
      }
      json = .object(dict)
    }

    request.httpBody = try URLEncodedFormEncoder(
      arrayEncoding: .noBrackets,
      keyEncoding: .convertToSnakeCase
    ).encode(json)
  }
}
