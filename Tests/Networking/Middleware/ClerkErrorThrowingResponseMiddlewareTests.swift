//
//  ClerkErrorThrowingResponseMiddlewareTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkErrorThrowingResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func throwsClerkAPIErrorOn400() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "form_param_missing",
          message: "Parameter missing",
          longMessage: "The parameter 'email' is required"
        )
      ],
      clerkTraceId: "trace_abc123"
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 400,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    do {
      try await middleware.validate(response, data: jsonData, for: request)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as ClerkAPIError {
      #expect(error.code == "form_param_missing")
      #expect(error.message == "Parameter missing")
      #expect(error.clerkTraceId == "trace_abc123")
    }
  }

  @Test
  func throwsClerkAPIErrorOn500() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "internal_error",
          message: "Internal server error",
          longMessage: nil
        )
      ],
      clerkTraceId: "trace_xyz789"
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 500,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    do {
      try await middleware.validate(response, data: jsonData, for: request)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as ClerkAPIError {
      #expect(error.code == "internal_error")
      #expect(error.clerkTraceId == "trace_xyz789")
    }
  }

  @Test
  func doesNotThrowOn200() async throws {
    let successData = try JSONEncoder.clerkEncoder.encode([
      "status": "ok",
      "data": "success"
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    // Should not throw
    try await middleware.validate(response, data: successData, for: request)
  }

  @Test
  func throwsURLErrorWhenCannotDecodeClerkError() async throws {
    let invalidData = Data([0x00, 0x01, 0x02])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 400,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    do {
      try await middleware.validate(response, data: invalidData, for: request)
      #expect(Bool(false), "Should have thrown an error")
    } catch is URLError {
      // Expected
    }
  }

  @Test
  func doesNotThrowOn201() async throws {
    let successData = try JSONEncoder.clerkEncoder.encode([
      "status": "created"
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 201,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    // Should not throw
    try await middleware.validate(response, data: successData, for: request)
  }

  @Test
  func throwsClerkAPIErrorOn401() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "authentication_invalid",
          message: "Invalid authentication",
          longMessage: nil
        )
      ],
      clerkTraceId: nil
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 401,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    do {
      try await middleware.validate(response, data: jsonData, for: request)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as ClerkAPIError {
      #expect(error.code == "authentication_invalid")
    }
  }

  @Test
  func throwsClerkAPIErrorOn403() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "authorization_invalid",
          message: "Forbidden",
          longMessage: nil
        )
      ],
      clerkTraceId: nil
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 403,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkErrorThrowingResponseMiddleware()

    do {
      try await middleware.validate(response, data: jsonData, for: request)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as ClerkAPIError {
      #expect(error.code == "authorization_invalid")
    }
  }
}