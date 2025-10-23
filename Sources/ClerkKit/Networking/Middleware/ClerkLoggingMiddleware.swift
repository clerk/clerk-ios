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
    let debugContext = await Task { @MainActor () -> (Bool, String?, String?) in
      (
        Clerk.shared.settings.debugMode,
        Clerk.shared.client?.id,
        try? Container.shared.keychain().string(forKey: "clerkDeviceToken")
      )
    }.value

    if let deviceToken = debugContext.2 {
      request.setValue(deviceToken, forHTTPHeaderField: "Authorization")
    }

    if debugContext.0, let clientId = debugContext.1 {
      request.setValue(clientId, forHTTPHeaderField: "x-clerk-client-id")
    }

    let nativeDeviceId = await Task { @MainActor in deviceID }.value
    request.setValue(nativeDeviceId, forHTTPHeaderField: "x-native-device-id")

    guard debugContext.0 else { return }

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

    Task { @MainActor in
      guard Clerk.shared.settings.debugMode else { return }
      ClerkLogger.debug(message, debugMode: true)
    }
  }
}

/// Logs incoming responses when debug mode is enabled.
struct ClerkResponseLoggingMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
    let url = response.url?.absoluteString ?? "<unknown url>"
    let status = response.statusCode

    var message = "⬅️ Response: \(status) \(url)"

    if let request = task.originalRequest,
       let method = request.httpMethod
    {
      message = "⬅️ Response: \(status) \(method) \(url)"
    }

    if !data.isEmpty,
       let body = String(data: data, encoding: .utf8),
       !body.isEmpty
    {
      message += " | Body: \(body)"
    }

    Task { @MainActor in
      guard Clerk.shared.settings.debugMode else { return }
      ClerkLogger.debug(message, debugMode: true)
    }
  }
}
