//
//  ClerkRateLimitRetryMiddlewareTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkRateLimitRetryMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func shouldRetryForRateLimit429() async throws {
    let sleepCalled = LockIsolated(false)
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepCalled.setValue(true)
      sleepDelay.setValue(delay)
    }

    let request = try URLRequest(url: #require(URL(string: "https://example.com")))
    let response = try HTTPURLResponse(
      url: #require(request.url),
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
  func shouldRetryForServerError500() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }

    let request = try URLRequest(url: #require(URL(string: "https://example.com")))
    let response = try HTTPURLResponse(
      url: #require(request.url),
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
  func shouldRetryForRetryableStatusCodes() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try URLRequest(url: #require(URL(string: "https://example.com")))

    let retryableCodes = [408, 425, 429, 500, 502, 503, 504]

    for statusCode in retryableCodes {
      let response = try HTTPURLResponse(
        url: #require(request.url),
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
  func shouldNotRetryForNonRetryableStatusCodes() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try URLRequest(url: #require(URL(string: "https://example.com")))

    let nonRetryableCodes = [400, 401, 403, 404, 422]

    for statusCode in nonRetryableCodes {
      let response = try HTTPURLResponse(
        url: #require(request.url),
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
  func shouldNotRetryOnSecondAttempt() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try URLRequest(url: #require(URL(string: "https://example.com")))
    let response = try HTTPURLResponse(
      url: #require(request.url),
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
  func retryDelayFromRetryAfterHeader() async throws {
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepDelay.setValue(delay)
    }

    let request = try URLRequest(url: #require(URL(string: "https://example.com")))
    let response = try HTTPURLResponse(
      url: #require(request.url),
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
  func retryDelayFromXRateLimitResetHeader() async throws {
    let sleepDelay = LockIsolated<UInt64?>(nil)
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    let middleware = ClerkRateLimitRetryMiddleware(
      sleep: { delay in sleepDelay.setValue(delay) },
      currentDate: { now }
    )

    let request = try URLRequest(url: #require(URL(string: "https://example.com")))
    let response = try HTTPURLResponse(
      url: #require(request.url),
      statusCode: 429,
      httpVersion: nil,
      headerFields: ["X-RateLimit-Reset": "1700000002"]
    )

    _ = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )

    #expect(sleepDelay.value == 2_000_000_000)
  }

  @Test
  func retryDelayDefaultsToHalfSecond() async throws {
    let sleepDelay = LockIsolated<UInt64?>(nil)

    let middleware = ClerkRateLimitRetryMiddleware { delay in
      sleepDelay.setValue(delay)
    }

    let request = try URLRequest(url: #require(URL(string: "https://example.com")))
    let response = try HTTPURLResponse(
      url: #require(request.url),
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
  func shouldRetryForRetryableURLErrors() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try URLRequest(url: #require(URL(string: "https://example.com")))

    let retryableErrors: [URLError.Code] = [
      .timedOut,
      .cannotFindHost,
      .cannotConnectToHost,
      .networkConnectionLost,
      .dnsLookupFailed,
      .notConnectedToInternet,
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
  func shouldNotRetryForNonRetryableURLErrors() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try URLRequest(url: #require(URL(string: "https://example.com")))

    let nonRetryableErrors: [URLError.Code] = [
      .badURL,
      .badServerResponse,
      .cancelled,
      .fileDoesNotExist,
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

  @Test(arguments: ["POST", "PATCH", "DELETE"])
  func nonSafeMethodDoesNotRetryServerErrors(method: String) async throws {
    let sleepCalled = LockIsolated(false)
    let middleware = ClerkRateLimitRetryMiddleware { _ in sleepCalled.setValue(true) }
    let request = try makeRequest(method: method)

    for statusCode in [500, 502, 503, 504] {
      let response = try HTTPURLResponse(
        url: #require(request.url),
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

      #expect(shouldRetry == false, "\(method) with status \(statusCode) should not retry")
    }

    #expect(sleepCalled.value == false)
  }

  @Test(arguments: ["POST", "PATCH", "DELETE"])
  func nonSafeMethodDoesNotRetryErrorsThatCanFollowServerProcessing(method: String) async throws {
    let sleepCalled = LockIsolated(false)
    let middleware = ClerkRateLimitRetryMiddleware { _ in sleepCalled.setValue(true) }
    let request = try makeRequest(method: method)

    for errorCode in [URLError.Code.timedOut, .networkConnectionLost] {
      let shouldRetry = try await middleware.shouldRetry(
        request: request,
        response: nil,
        error: URLError(errorCode),
        attempts: 1
      )

      #expect(shouldRetry == false, "\(method) with URLError \(errorCode.rawValue) should not retry")
    }

    #expect(sleepCalled.value == false)
  }

  @Test(arguments: ["POST", "PATCH", "DELETE"])
  func nonSafeMethodRetriesStatusCodesTheServerDidNotProcess(method: String) async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try makeRequest(method: method)

    for statusCode in [408, 425, 429] {
      let response = try HTTPURLResponse(
        url: #require(request.url),
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

      #expect(shouldRetry == true, "\(method) with status \(statusCode) should retry")
    }
  }

  @Test(arguments: ["POST", "PATCH", "DELETE"])
  func nonSafeMethodRetriesConnectPhaseErrors(method: String) async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try makeRequest(method: method)

    let connectPhaseErrors: [URLError.Code] = [
      .cannotFindHost,
      .cannotConnectToHost,
      .dnsLookupFailed,
      .notConnectedToInternet,
    ]

    for errorCode in connectPhaseErrors {
      let shouldRetry = try await middleware.shouldRetry(
        request: request,
        response: nil,
        error: URLError(errorCode),
        attempts: 1
      )

      #expect(shouldRetry == true, "\(method) with URLError \(errorCode.rawValue) should retry")
    }
  }

  @Test
  func headRetriesServerErrorAndTimeout() async throws {
    let middleware = ClerkRateLimitRetryMiddleware { _ in }
    let request = try makeRequest(method: "HEAD")
    let response = try HTTPURLResponse(
      url: #require(request.url),
      statusCode: 500,
      httpVersion: nil,
      headerFields: nil
    )

    let retriesServerError = try await middleware.shouldRetry(
      request: request,
      response: response,
      error: NSError(domain: "test", code: 0),
      attempts: 1
    )
    let retriesTimeout = try await middleware.shouldRetry(
      request: request,
      response: nil,
      error: URLError(.timedOut),
      attempts: 1
    )

    #expect(retriesServerError == true)
    #expect(retriesTimeout == true)
  }

  private func makeRequest(method: String) throws -> URLRequest {
    var request = try URLRequest(url: #require(URL(string: "https://example.com")))
    request.httpMethod = method
    return request
  }
}
