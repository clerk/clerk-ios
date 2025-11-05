//
//  ClerkRateLimitRetryMiddlewareTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Tests for ClerkRateLimitRetryMiddleware retry logic and delay calculations.
@MainActor
@Suite(.serialized)
struct ClerkRateLimitRetryMiddlewareTests {

  init() {
    configureClerkForTesting()
  }

  @Test
  func testShouldRetryForRateLimit429() async throws {
    let sleepCalled = LockIsolated(false)
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepCalled.setValue(true)
      sleepDelay.setValue(delay)
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 429,
      httpVersion: nil,
      headerFields: nil
    )

    let shouldRetry = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )

    #expect(shouldRetry == true)
    #expect(sleepCalled.value == true)
    #expect(sleepDelay.value != nil)
  }

  @Test
  func testShouldRetryForServerError500() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in /* no-op */ }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 500,
      httpVersion: nil,
      headerFields: nil
    )

    let shouldRetry = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )

    #expect(shouldRetry == true)
  }

  @Test
  func testShouldRetryForRetryableStatusCodes() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in /* no-op */ }
    let request = URLRequest(url: URL(string: "https://example.com")!)

    let retryableCodes = [408, 425, 429, 500, 502, 503, 504]

    for statusCode in retryableCodes {
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      )

      let shouldRetry = try await middleware.shouldRetry(
        request: request,
        response: response,
        error: NSError(domain: "test", code: 0),
        attempts: 1
      )

      #expect(shouldRetry == true, "Status code \(statusCode) should trigger retry")
    }
  }

  @Test
  func testShouldNotRetryForNonRetryableStatusCodes() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in /* no-op */ }
    let request = URLRequest(url: URL(string: "https://example.com")!)

    let nonRetryableCodes = [400, 401, 403, 404, 422]

    for statusCode in nonRetryableCodes {
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      )

      let shouldRetry = try await middleware.shouldRetry(
        request: request,
        response: response,
        error: NSError(domain: "test", code: 0),
        attempts: 1
      )

      #expect(shouldRetry == false, "Status code \(statusCode) should not trigger retry")
    }
  }

  @Test
  func testShouldNotRetryOnSecondAttempt() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in /* no-op */ }
    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 429,
      httpVersion: nil,
      headerFields: nil
    )

    let shouldRetry = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 2
    )

    #expect(shouldRetry == false, "Should not retry on second attempt")
  }

  @Test
  func testRetryDelayFromRetryAfterHeader() async throws {
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepDelay.setValue(delay)
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 429,
      httpVersion: nil,
      headerFields: ["Retry-After": "2"]
    )

    _ = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )

    // Should delay for approximately 2 seconds (2 billion nanoseconds)
    #expect(sleepDelay.value != nil)
    if let delay = sleepDelay.value {
      // Allow some tolerance for timing variance
      #expect(delay >= 1_900_000_000, "Delay should be approximately 2 seconds")
      #expect(delay <= 2_200_000_000, "Delay should be approximately 2 seconds")
    }
  }

  @Test
  func testRetryDelayFromXRateLimitResetHeader() async throws {
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepDelay.setValue(delay)
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    // Set reset time to 2 seconds in the future
    let resetTime = Date().timeIntervalSince1970 + 2.0
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 429,
      httpVersion: nil,
      headerFields: ["X-RateLimit-Reset": String(format: "%.0f", resetTime)]
    )

    _ = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )

    // Should delay for approximately 2 seconds (some time may have passed)
    #expect(sleepDelay.value != nil)
    if let delay = sleepDelay.value {
      // Allow tolerance for timing variance - delay should be approximately 2 seconds
      // (accounting for time that may have passed between setting resetTime and calculation)
      // The delay is clamped between 0.1s and 5s, so we check it's in a reasonable range
      #expect(delay >= 1_500_000_000, "Delay should be approximately 2 seconds")
      #expect(delay <= 2_500_000_000, "Delay should be approximately 2 seconds")
    }
  }

  @Test
  func testRetryDelayDefaultsToHalfSecond() async throws {
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepDelay.setValue(delay)
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 429,
      httpVersion: nil,
      headerFields: nil
    )

    _ = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )

    // Should default to 0.5 seconds (500 million nanoseconds)
    #expect(sleepDelay.value != nil)
    if let delay = sleepDelay.value {
      #expect(delay == 500_000_000, "Default delay should be 0.5 seconds")
    }
  }

  @Test
  func testShouldRetryForRetryableURLErrors() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in /* no-op */ }
    let request = URLRequest(url: URL(string: "https://example.com")!)

    let retryableErrors: [URLError.Code] = [
      .timedOut,
      .cannotFindHost,
      .cannotConnectToHost,
      .networkConnectionLost,
      .dnsLookupFailed,
      .notConnectedToInternet
    ]

    for errorCode in retryableErrors {
      let error = URLError(errorCode)
      let shouldRetry = try await middleware.shouldRetry(
        request: request,
        response: nil,
        error: error,
        attempts: 1
      )

      #expect(shouldRetry == true, "URLError \(errorCode.rawValue) should trigger retry")
    }
  }

  @Test
  func testShouldNotRetryForNonRetryableURLErrors() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in /* no-op */ }
    let request = URLRequest(url: URL(string: "https://example.com")!)

    let nonRetryableErrors: [URLError.Code] = [
      .badURL,
      .badServerResponse,
      .cancelled,
      .fileDoesNotExist
    ]

    for errorCode in nonRetryableErrors {
      let error = URLError(errorCode)
      let shouldRetry = try await middleware.shouldRetry(
        request: request,
        response: nil,
        error: error,
        attempts: 1
      )

      #expect(shouldRetry == false, "URLError \(errorCode.rawValue) should not trigger retry")
    }
  }
}
