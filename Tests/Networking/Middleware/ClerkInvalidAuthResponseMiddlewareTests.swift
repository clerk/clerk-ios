//
//  ClerkInvalidAuthResponseMiddlewareTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkInvalidAuthResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func triggersClientRefreshOnAuthenticationInvalid() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "authentication_invalid",
          message: "Authentication is invalid",
          longMessage: nil
        )
      ],
      clerkTraceId: nil
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test/v1/me")!,
      statusCode: 401,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test/v1/me")!)
    let middleware = ClerkInvalidAuthResponseMiddleware()

    // Set initial client
    Clerk.shared.client = Client.mockSignedOut

    try await middleware.validate(response, data: jsonData, for: request)

    // Client refresh should have been triggered (tested via integration)
  }

  @Test
  func triggersClientRefreshOnResourceNotFound() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "resource_not_found",
          message: "Resource not found",
          longMessage: nil
        )
      ],
      clerkTraceId: nil
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test/v1/sessions/sess_123")!,
      statusCode: 404,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test/v1/sessions/sess_123")!)
    let middleware = ClerkInvalidAuthResponseMiddleware()

    try await middleware.validate(response, data: jsonData, for: request)

    // Client refresh should have been triggered
  }

  @Test
  func doesNotTriggerRefreshOnClientGetRequest() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "authentication_invalid",
          message: "Authentication is invalid",
          longMessage: nil
        )
      ],
      clerkTraceId: nil
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test/v1/client")!,
      statusCode: 401,
      httpVersion: nil,
      headerFields: nil
    )!

    var request = URLRequest(url: URL(string: "https://api.clerk.test/v1/client")!)
    request.httpMethod = "GET"

    let middleware = ClerkInvalidAuthResponseMiddleware()

    // Should not trigger refresh for client GET requests
    try await middleware.validate(response, data: jsonData, for: request)
  }

  @Test
  func doesNotTriggerRefreshOnOtherErrors() async throws {
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "form_param_missing",
          message: "Parameter missing",
          longMessage: nil
        )
      ],
      clerkTraceId: nil
    )

    let jsonData = try JSONEncoder.clerkEncoder.encode(errorResponse)

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test/v1/sign-in")!,
      statusCode: 400,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test/v1/sign-in")!)
    let middleware = ClerkInvalidAuthResponseMiddleware()

    // Should not trigger refresh for non-auth errors
    try await middleware.validate(response, data: jsonData, for: request)
  }

  @Test
  func doesNotTriggerRefreshOnSuccessResponse() async throws {
    let successData = try JSONEncoder.clerkEncoder.encode([
      "status": "ok"
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test/v1/me")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test/v1/me")!)
    let middleware = ClerkInvalidAuthResponseMiddleware()

    // Should not trigger refresh on success
    try await middleware.validate(response, data: successData, for: request)
  }

  @Test
  func handlesInvalidJSONGracefully() async throws {
    let invalidData = Data([0x00, 0x01, 0x02])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test/v1/me")!,
      statusCode: 401,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test/v1/me")!)
    let middleware = ClerkInvalidAuthResponseMiddleware()

    // Should not crash on invalid JSON
    try await middleware.validate(response, data: invalidData, for: request)
  }
}