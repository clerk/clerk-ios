//
//  ClerkLoggingMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkRequestLoggingMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    let method = request.httpMethod ?? "GET"
    let url = request.url?.absoluteString ?? "<unknown url>"

    let basicMessage = "➡️ Request: \(method) \(url)"
    ClerkLogger.info(basicMessage)

    if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
      let sanitized = headers
        .filter { key, _ in key.caseInsensitiveCompare("Authorization") != .orderedSame }
        .map { "\($0): \($1)" }
        .joined(separator: ", ")

      if !sanitized.isEmpty {
        let headersMessage = "➡️ Request Headers: [\(sanitized)]"
        ClerkLogger.verbose(headersMessage)
      }
    }

    if request.shouldLogClerkBodies,
       let body = request.httpBody,
       let bodyString = String(data: body, encoding: .utf8),
       !bodyString.isEmpty
    {
      let bodyMessage = "➡️ Request Body: \(bodyString)"
      ClerkLogger.verbose(bodyMessage)
    }
  }
}

struct ClerkResponseLoggingMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    let url = response.url?.absoluteString ?? "<unknown url>"
    let status = response.statusCode

    var basicMessage = "⬅️ Response: \(status) \(url)"
    if let method = request.httpMethod {
      basicMessage = "⬅️ Response: \(status) \(method) \(url)"
    }

    ClerkLogger.info(basicMessage)

    if request.shouldLogClerkBodies,
       !data.isEmpty,
       let body = String(data: data, encoding: .utf8),
       !body.isEmpty
    {
      let bodyMessage = "⬅️ Response Body: \(body)"
      ClerkLogger.verbose(bodyMessage)
    }
  }
}
