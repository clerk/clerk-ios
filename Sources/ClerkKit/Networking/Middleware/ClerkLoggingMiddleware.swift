//
//  ClerkLoggingMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkRequestLoggingMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    let method = request.httpMethod ?? "GET"
    let url = ClerkLogRedaction.redactingSecrets(in: request.url?.absoluteString ?? "<unknown url>")

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
      let bodyMessage = "➡️ Request Body: \(ClerkLogRedaction.redactingSecrets(in: bodyString))"
      ClerkLogger.verbose(bodyMessage)
    }
  }
}

struct ClerkResponseLoggingMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    let url = ClerkLogRedaction.redactingSecrets(in: response.url?.absoluteString ?? "<unknown url>")
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
      let bodyMessage = "⬅️ Response Body: \(ClerkLogRedaction.redactingSecrets(in: body))"
      ClerkLogger.verbose(bodyMessage)
    }
  }
}

enum ClerkLogRedaction {
  static let placeholder = "██"

  private static let sensitiveFormFields = [
    "password",
    "current_password",
    "new_password",
    "code",
    "token",
    "ticket",
    "code_verifier",
    "id_token",
    "approval_token",
    "rotating_token_nonce",
    "signature",
  ]

  private static let sensitiveJSONKeys = [
    "password",
    "jwt",
    "secret",
    "token",
    "ticket",
    "code_verifier",
    "id_token",
    "approval_token",
  ]

  private static let rules: [(pattern: NSRegularExpression, template: String)] = [
    (
      regex("(^|[?&])(\(sensitiveFormFields.joined(separator: "|")))=[^&\\s]*"),
      "$1$2=\(placeholder)"
    ),
    (
      regex(#"("(?:\#(sensitiveJSONKeys.joined(separator: "|")))"\s*:\s*)"(?:[^"\\]|\\.)*""#),
      "$1\"\(placeholder)\""
    ),
    (
      regex(#"("(?:backup_codes|codes)"\s*:\s*)\[[^\]]*\]"#),
      "$1[\"\(placeholder)\"]"
    ),
    (
      regex(#"otpauth:[^"\s]*"#),
      placeholder
    ),
  ]

  static func redactingSecrets(in text: String) -> String {
    rules.reduce(text) { text, rule in
      rule.pattern.stringByReplacingMatches(
        in: text,
        range: NSRange(text.startIndex..., in: text),
        withTemplate: rule.template
      )
    }
  }

  private static func regex(_ pattern: String) -> NSRegularExpression {
    do {
      return try NSRegularExpression(pattern: pattern)
    } catch {
      preconditionFailure("Invalid log redaction pattern \(pattern): \(error)")
    }
  }
}
