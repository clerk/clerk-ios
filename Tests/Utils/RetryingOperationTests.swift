//
//  RetryingOperationTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct RetryingOperationTests {
  @Test
  @MainActor
  func retriesUntilSuccess() async throws {
    let policy = RetryPolicy(maxAttempts: 3, initialDelay: .zero, maximumDelay: .zero)
    let counter = AttemptCounter()

    let value = try await retryingOperation(policy: policy, operationName: "test") {
      let attempts = await counter.incrementAndGet()
      if attempts < 2 {
        throw TestError.sample
      }
      return "ok"
    }

    #expect(value == "ok")
    #expect(await counter.value == 2)
  }

  @Test
  @MainActor
  func stopsAfterMaxAttempts() async {
    let policy = RetryPolicy(maxAttempts: 2, initialDelay: .zero, maximumDelay: .zero)
    let counter = AttemptCounter()

    do {
      _ = try await retryingOperation(policy: policy, operationName: "test") {
        _ = await counter.incrementAndGet()
        throw TestError.sample
      }
      #expect(Bool(false), "Expected retryingOperation to throw after max attempts")
    } catch is TestError {
      #expect(await counter.value == 2)
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }
  }

  @Test(arguments: [400, 404, 422, 429])
  @MainActor
  func doesNotRetryErrorsTheServerRejected(statusCode: Int) async {
    let policy = RetryPolicy(maxAttempts: 3, initialDelay: .zero, maximumDelay: .zero)
    let counter = AttemptCounter()

    await #expect(throws: ClerkAPIError.self) {
      try await retryingOperation(policy: policy, operationName: "test") {
        _ = await counter.incrementAndGet()
        throw apiError(statusCode: statusCode)
      }
    }
    #expect(await counter.value == 1)
  }

  @Test(arguments: [404, 500])
  @MainActor
  func treatsAnErrorResponseWithoutAClerkBodyByItsStatus(statusCode: Int) async {
    let policy = RetryPolicy(maxAttempts: 3, initialDelay: .zero, maximumDelay: .zero)
    let counter = AttemptCounter()

    await #expect(throws: URLError.self) {
      try await retryingOperation(policy: policy, operationName: "test") {
        _ = await counter.incrementAndGet()
        throw URLError(.unknown, userInfo: [URLError.clerkStatusCodeKey: statusCode])
      }
    }
    #expect(await counter.value == (statusCode < 500 ? 1 : 3))
  }

  @Test(arguments: [500, 503, nil] as [Int?])
  @MainActor
  func retriesServerErrorsAndErrorsWithoutAStatus(statusCode: Int?) async {
    let policy = RetryPolicy(maxAttempts: 3, initialDelay: .zero, maximumDelay: .zero)
    let counter = AttemptCounter()

    await #expect(throws: ClerkAPIError.self) {
      try await retryingOperation(policy: policy, operationName: "test") {
        _ = await counter.incrementAndGet()
        throw apiError(statusCode: statusCode)
      }
    }
    #expect(await counter.value == 3)
  }

  @Test
  func policySanitizesInputs() {
    let policy = RetryPolicy(maxAttempts: 0, initialDelay: .seconds(-1), maximumDelay: .seconds(-2))

    #expect(policy.maxAttempts == 1)
    #expect(milliseconds(from: policy.initialDelay) == 0)
    #expect(milliseconds(from: policy.maximumDelay) == 0)
  }

  @Test
  func delaysClampToMaximum() {
    let policy = RetryPolicy(maxAttempts: 5, initialDelay: .milliseconds(250), maximumDelay: .seconds(1))

    #expect(milliseconds(from: policy.delay(forAttempt: 1)) == 250)
    #expect(milliseconds(from: policy.delay(forAttempt: 2)) == 500)
    #expect(milliseconds(from: policy.delay(forAttempt: 3)) == 1000)
    #expect(milliseconds(from: policy.delay(forAttempt: 4)) == 1000)
  }

  private func milliseconds(from duration: Duration) -> Int {
    let components = duration.components
    let seconds = Double(components.seconds)
    let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
    return Int(((seconds + attoseconds) * 1000).rounded())
  }
}

private func apiError(statusCode: Int?) -> ClerkAPIError {
  var error = ClerkAPIError(code: "test_error")
  error.statusCode = statusCode
  return error
}

private enum TestError: Error {
  case sample
}

private actor AttemptCounter {
  private(set) var value = 0

  func incrementAndGet() -> Int {
    value += 1
    return value
  }
}
