//
//  ClerkLoggingMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 10/23/25.
//

import FactoryKit
import Foundation

/// Logs outgoing requests when debug mode is enabled.
struct ClerkRequestLoggingMiddleware: NetworkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
  let debugEnabled = await Task { @MainActor in Clerk.shared.options.debugMode }.value
  guard debugEnabled else { return }

  let method = request.httpMethod ?? "GET"
  let url = request.url?.absoluteString ?? "<unknown url>"

  var message = "➡️ Request: \(method) \(url)"

  if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
    let sanitized = headers
    .filter { key, _ in key.caseInsensitiveCompare("Authorization") != .orderedSame }
    .map { "\($0): \($1)" }
    .joined(separator: ", ")

    if !sanitized.isEmpty {
    message += " | Headers: [\(sanitized)]"
    }
  }

  if let body = request.httpBody,
    let bodyString = String(data: body, encoding: .utf8),
    !bodyString.isEmpty
  {
    message += " | Body: \(bodyString)"
  }

  ClerkLogger.debug(message, debugMode: true)
  }
}

/// Logs incoming responses when debug mode is enabled.
struct ClerkResponseLoggingMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
  let url = response.url?.absoluteString ?? "<unknown url>"
  let status = response.statusCode

  var message = "⬅️ Response: \(status) \(url)"

  if let method = request.httpMethod {
    message = "⬅️ Response: \(status) \(method) \(url)"
  }

  if !data.isEmpty,
    let body = String(data: data, encoding: .utf8),
    !body.isEmpty
  {
    message += " | Body: \(body)"
  }

  Task { @MainActor in
    guard Clerk.shared.options.debugMode else { return }
    ClerkLogger.debug(message, debugMode: true)
  }
  }
}
