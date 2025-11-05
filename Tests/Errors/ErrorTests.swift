//
//  ErrorTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ErrorTests {
  // MARK: - ClerkError Protocol

  @Test
  func clerkErrorProtocol() {
    let error = ClerkClientError(message: "Test error")

    #expect(error.message != nil)
    #expect(error.message == "Test error")
    #expect(error.underlyingError == nil)
    #expect(error.context == nil)
  }

  // MARK: - ClerkAPIError Tests

  @Test
  func clerkAPIErrorBasic() {
    let error = ClerkAPIError(
      code: "test_error",
      message: "Test message",
      longMessage: "Long test message",
      meta: nil,
      clerkTraceId: "trace123"
    )

    #expect(error.code == "test_error")
    #expect(error.message == "Test message")
    #expect(error.longMessage == "Long test message")
    #expect(error.clerkTraceId == "trace123")
  }

  @Test
  func clerkAPIErrorContext() {
    let error = ClerkAPIError(
      code: "test_error",
      message: "Test message",
      longMessage: nil,
      meta: JSON.object(["param_name": .string("email")]),
      clerkTraceId: "trace123"
    )

    let context = error.context
    #expect(context != nil)
    #expect(context?["traceId"] == "trace123")
    #expect(context?["paramName"] == "email")
  }

  @Test
  func clerkAPIErrorErrorDescription() {
    let error1 = ClerkAPIError(
      code: "test_error",
      message: "Short message",
      longMessage: "Long message",
      meta: nil,
      clerkTraceId: nil
    )

    #expect(error1.errorDescription == "Long message")

    let error2 = ClerkAPIError(
      code: "test_error",
      message: "Short message",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    #expect(error2.errorDescription == "Short message")
  }

  @Test
  func clerkAPIErrorCodable() throws {
    let error = ClerkAPIError(
      code: "test_error",
      message: "Test message",
      longMessage: "Long message",
      meta: JSON.object(["key": .string("value")]),
      clerkTraceId: "trace123"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(error)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ClerkAPIError.self, from: data)

    #expect(decoded.code == error.code)
    #expect(decoded.message == error.message)
    #expect(decoded.longMessage == error.longMessage)
    #expect(decoded.clerkTraceId == error.clerkTraceId)
  }

  @Test
  func clerkAPIErrorEquatable() {
    let error1 = ClerkAPIError(
      code: "test_error",
      message: "Test message",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    let error2 = ClerkAPIError(
      code: "test_error",
      message: "Test message",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    #expect(error1 == error2)

    let error3 = ClerkAPIError(
      code: "different_error",
      message: "Test message",
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    #expect(error1 != error3)
  }

  @Test
  func clerkErrorResponse() throws {
    let response = ClerkErrorResponse(
      errors: [
        ClerkAPIError(code: "error1", message: "Message 1", longMessage: nil, meta: nil, clerkTraceId: nil),
        ClerkAPIError(code: "error2", message: "Message 2", longMessage: nil, meta: nil, clerkTraceId: nil),
      ],
      clerkTraceId: "trace123"
    )

    #expect(response.errors.count == 2)
    #expect(response.clerkTraceId == "trace123")

    // Test Codable
    let encoder = JSONEncoder()
    let data = try encoder.encode(response)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ClerkErrorResponse.self, from: data)

    #expect(decoded.errors.count == 2)
    #expect(decoded.clerkTraceId == "trace123")
  }

  // MARK: - ClerkClientError Tests

  @Test
  func clerkClientError() {
    let error = ClerkClientError(message: "Test error")

    #expect(error.messageLocalizationValue != nil)
    #expect(error.message == "Test error")
    #expect(error.context == nil)
  }

  @Test
  func clerkClientErrorErrorDescription() {
    let error = ClerkClientError(message: "Test error")

    #expect(error.errorDescription == "Test error")
  }

  @Test
  func clerkClientErrorNilMessage() {
    let error = ClerkClientError(message: nil)

    #expect(error.message == nil)
    #expect(error.errorDescription == nil)
  }

  // MARK: - ClerkInitializationError Tests

  @Test
  func clerkInitializationErrorMissingPublishableKey() {
    let error = ClerkInitializationError.missingPublishableKey

    #expect(error.message != nil)
    #expect(error.message == error.errorDescription)
    #expect(error.underlyingError == nil)
    #expect(error.context == nil)
    #expect(error.failureReason != nil)
  }

  @Test
  func clerkInitializationErrorInvalidPublishableKeyFormat() {
    let error = ClerkInitializationError.invalidPublishableKeyFormat(key: "invalid_key")

    #expect(error.message != nil)
    #expect(error.message == error.errorDescription)
    #expect(error.underlyingError == nil)
    #expect(error.context != nil)
    #expect(error.context?["key"] == "invalid_key")
  }

  @Test
  func clerkInitializationErrorClientLoadFailed() {
    let underlyingError = NSError(domain: "test", code: 1)
    let error = ClerkInitializationError.clientLoadFailed(underlyingError: underlyingError)

    #expect(error.message != nil)
    #expect(error.underlyingError != nil)
    #expect(error.context == nil)
  }

  @Test
  func clerkInitializationErrorEnvironmentLoadFailed() {
    let underlyingError = NSError(domain: "test", code: 1)
    let error = ClerkInitializationError.environmentLoadFailed(underlyingError: underlyingError)

    #expect(error.message != nil)
    #expect(error.underlyingError != nil)
    #expect(error.context == nil)
  }

  @Test
  func clerkInitializationErrorAPIClientInitializationFailed() {
    let error = ClerkInitializationError.apiClientInitializationFailed(reason: "Network error")

    #expect(error.message != nil)
    #expect(error.underlyingError == nil)
    #expect(error.context != nil)
    #expect(error.context?["reason"] == "Network error")
  }

  @Test
  func clerkInitializationErrorInitializationFailed() {
    let underlyingError = NSError(domain: "test", code: 1)
    let error = ClerkInitializationError.initializationFailed(underlyingError: underlyingError)

    #expect(error.message != nil)
    #expect(error.underlyingError != nil)
    #expect(error.context == nil)
  }

  @Test
  func clerkInitializationErrorLocalizedError() {
    let error = ClerkInitializationError.missingPublishableKey

    #expect(error.errorDescription != nil)
    #expect(error.failureReason != nil)
    #expect(error.localizedDescription == error.errorDescription)
  }
}
