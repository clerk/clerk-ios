//
//  ClerkLoggingMiddlewareTests.swift
//  Clerk
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

struct ClerkLogRedactionTests {
  private let redacted = ClerkLogRedaction.placeholder

  @Test
  func signInPasswordIsRedactedFromFormBodies() {
    let body = "identifier=user%40example.com&password=hunter2&strategy=password"

    #expect(
      ClerkLogRedaction.redactingSecrets(in: body)
        == "identifier=user%40example.com&password=\(redacted)&strategy=password"
    )
  }

  @Test
  func passwordChangeFieldsAreRedactedFromFormBodies() {
    let body = "current_password=old-secret&new_password=new-secret&sign_out_of_other_sessions=true"

    #expect(
      ClerkLogRedaction.redactingSecrets(in: body)
        == "current_password=\(redacted)&new_password=\(redacted)&sign_out_of_other_sessions=true"
    )
  }

  @Test
  func verificationCodesAndTicketsAreRedactedFromFormBodies() {
    #expect(
      ClerkLogRedaction.redactingSecrets(in: "strategy=email_code&code=424242")
        == "strategy=email_code&code=\(redacted)"
    )
    #expect(
      ClerkLogRedaction.redactingSecrets(in: "strategy=ticket&ticket=abc.def")
        == "strategy=ticket&ticket=\(redacted)"
    )
  }

  @Test
  func similarlyNamedFormFieldsStayReadable() {
    let body = "password_strength=weak&codes_sent=1"

    #expect(ClerkLogRedaction.redactingSecrets(in: body) == body)
  }

  @Test
  func sensitiveQueryItemsAreRedactedFromURLs() {
    let url = "https://clerk.example.com/v1/client?token=abc&_clerk_session_id=sess_123"

    #expect(
      ClerkLogRedaction.redactingSecrets(in: url)
        == "https://clerk.example.com/v1/client?token=\(redacted)&_clerk_session_id=sess_123"
    )
  }

  @Test
  func sessionJWTsAreRedactedFromClientResponses() {
    let body = #"{"sessions":[{"id":"sess_123","status":"active","last_active_token":{"object":"token","jwt":"eyJhbGciOi.payload.sig"}}]}"#

    #expect(
      ClerkLogRedaction.redactingSecrets(in: body)
        == #"{"sessions":[{"id":"sess_123","status":"active","last_active_token":{"object":"token","jwt":"\#(redacted)"}}]}"#
    )
  }

  @Test
  func escapedQuotesInsideSecretsAreRedactedWithTheValue() {
    let body = #"{"jwt":"abc\"def","id":"sess_123"}"#

    #expect(ClerkLogRedaction.redactingSecrets(in: body) == #"{"jwt":"\#(redacted)","id":"sess_123"}"#)
  }

  @Test
  func totpSecretsAndBackupCodesAreRedactedFromResponses() {
    let body = #"{"secret":"JBSWY3DPEHPK3PXP","uri":"otpauth://totp/Clerk:user?secret=JBSWY3DPEHPK3PXP","backup_codes":["aaaa1111","bbbb2222"]}"#

    #expect(
      ClerkLogRedaction.redactingSecrets(in: body)
        == #"{"secret":"\#(redacted)","uri":"\#(redacted)","backup_codes":["\#(redacted)"]}"#
    )
  }

  @Test
  func totpURIsWithEscapedSlashesAreRedacted() throws {
    let data = try JSONEncoder().encode(["uri": "otpauth://totp/Clerk:user?secret=JBSWY3DPEHPK3PXP"])
    let body = try #require(String(data: data, encoding: .utf8))
    #expect(body.contains(#"otpauth:\/\/"#))

    #expect(ClerkLogRedaction.redactingSecrets(in: body) == #"{"uri":"\#(redacted)"}"#)
  }

  @Test
  func errorCodesAndSimilarlyNamedKeysStayReadable() {
    let body = #"{"errors":[{"code":"form_password_incorrect","message":"Password is incorrect."}],"token_type":"bearer"}"#

    #expect(ClerkLogRedaction.redactingSecrets(in: body) == body)
  }
}

@MainActor
@Suite(.serialized)
struct ClerkLoggingMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func requestsAreLoggedWithoutSecrets() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .verbose))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    var request = try URLRequest(url: #require(URL(string: "https://clerk.example.com/v1/client/sign_ins?ticket=tkt_secret")))
    request.httpMethod = "POST"
    request.httpBody = Data("identifier=user%40example.com&password=hunter2".utf8)
    try await ClerkRequestLoggingMiddleware().prepare(&request)

    let urlLine = try await #require(lines.firstLine(containing: "Request: POST"))
    #expect(urlLine.hasSuffix("/v1/client/sign_ins?ticket=\(ClerkLogRedaction.placeholder)"))
    #expect(!urlLine.contains("tkt_secret"))

    let bodyLine = try await #require(lines.firstLine(containing: "Request Body:"))
    #expect(bodyLine.hasSuffix("identifier=user%40example.com&password=\(ClerkLogRedaction.placeholder)"))
    #expect(!bodyLine.contains("hunter2"))
  }

  @Test
  func responsesAreLoggedWithoutSecrets() async throws {
    Clerk.configure(publishableKey: testPublishableKey, options: Clerk.Options(logLevel: .verbose))
    let (lines, restoreSink) = captureLogLines()
    defer { restoreSink() }

    let url = try #require(URL(string: "https://clerk.example.com/v1/client?token=tok_secret"))
    let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
    let body = Data(#"{"last_active_token":{"jwt":"eyJhbGciOi.payload.sig"}}"#.utf8)
    try await ClerkResponseLoggingMiddleware().validate(response, data: body, for: URLRequest(url: url))

    let urlLine = try await #require(lines.firstLine(containing: "Response: 200"))
    #expect(urlLine.hasSuffix("/v1/client?token=\(ClerkLogRedaction.placeholder)"))
    #expect(!urlLine.contains("tok_secret"))

    let bodyLine = try await #require(lines.firstLine(containing: "Response Body:"))
    #expect(bodyLine.hasSuffix(#"{"last_active_token":{"jwt":"\#(ClerkLogRedaction.placeholder)"}}"#))
    #expect(!bodyLine.contains("eyJhbGciOi"))
  }
}

extension LockIsolated<[String]> {
  fileprivate func firstLine(containing needle: String) async -> String? {
    for _ in 0 ..< 100 {
      if let line = value.first(where: { $0.contains(needle) }) {
        return line
      }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return nil
  }
}

@MainActor
private func captureLogLines() -> (LockIsolated<[String]>, @MainActor () -> Void) {
  let original = ClerkLogger.sink
  let lines = LockIsolated<[String]>([])
  ClerkLogger.sink = { _, text in
    lines.withValue { $0.append(text) }
  }
  return (lines, { ClerkLogger.sink = original })
}
