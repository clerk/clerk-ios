//
//  ClerkLogRedaction.swift
//  Clerk
//

import Foundation

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
    "public_key_credential",
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
      regex("(^|[?&\\s])(\(sensitiveFormFields.joined(separator: "|")))=[^&\\s]*"),
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
