//
//  ClerkLoggingMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 10/23/25.
//

import Foundation

/// Logs outgoing requests based on log level configuration.
struct ClerkRequestLoggingMiddleware: NetworkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    let method = request.httpMethod ?? "GET"
    let url = request.url?.absoluteString ?? "<unknown url>"

    // Log basic request info (method and URL only) at info level
    let basicMessage = "➡️ Request: \(method) \(url)"
    ClerkLogger.info(basicMessage)

    // Log headers and body at verbose level
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

    if let body = request.httpBody,
       let bodyString = String(data: body, encoding: .utf8),
       !bodyString.isEmpty
    {
      let bodyMessage = "➡️ Request Body: \(bodyString)"
      ClerkLogger.verbose(bodyMessage)
    }
  }
}

/// Logs incoming responses based on log level configuration.
struct ClerkResponseLoggingMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    let url = response.url?.absoluteString ?? "<unknown url>"
    let status = response.statusCode

    // Log basic response info at info level
    var basicMessage = "⬅️ Response: \(status) \(url)"
    if let method = request.httpMethod {
      basicMessage = "⬅️ Response: \(status) \(method) \(url)"
    }

    ClerkLogger.info(basicMessage)

    // Log response body at verbose level
    if !data.isEmpty,
       let body = String(data: data, encoding: .utf8),
       !body.isEmpty
    {
      let bodyMessage = "⬅️ Response Body: \(body)"
      ClerkLogger.verbose(bodyMessage)
    }
  }
}
