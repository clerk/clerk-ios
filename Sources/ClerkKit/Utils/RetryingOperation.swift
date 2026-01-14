//
//  RetryingOperation.swift
//  Clerk
//
//  Created by Assistant on 2025-01-27.
//

import Foundation

struct RetryPolicy: Sendable {
  let maxAttempts: Int
  let initialDelay: Duration
  let maximumDelay: Duration

  init(
    maxAttempts: Int,
    initialDelay: Duration,
    maximumDelay: Duration
  ) {
    let sanitizedMaxAttempts = max(1, maxAttempts)
    let sanitizedInitialDelay = max(.zero, initialDelay)
    let sanitizedMaximumDelay = max(sanitizedInitialDelay, maximumDelay)

    self.maxAttempts = sanitizedMaxAttempts
    self.initialDelay = sanitizedInitialDelay
    self.maximumDelay = sanitizedMaximumDelay
  }

  func delay(forAttempt attempt: Int) -> Duration {
    guard attempt > 0 else {
      return initialDelay
    }

    let baseSeconds = seconds(from: initialDelay)
    let maxSeconds = seconds(from: maximumDelay)
    let exponent = max(0, attempt - 1)
    let delaySeconds = min(maxSeconds, baseSeconds * pow(2, Double(exponent)))

    if delaySeconds <= 0 {
      return .zero
    }

    return .seconds(delaySeconds)
  }

  private func seconds(from duration: Duration) -> Double {
    let components = duration.components
    let seconds = Double(components.seconds)
    let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
    return seconds + attoseconds
  }
}

@MainActor
func retryingOperation<T>(
  policy: RetryPolicy,
  operationName: String,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  var attempt = 0

  while true {
    try Task.checkCancellation()
    attempt += 1

    do {
      return try await operation()
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      guard attempt < policy.maxAttempts else {
        throw error
      }

      let delay = policy.delay(forAttempt: attempt)
      let delayMs = delayMilliseconds(delay)
      ClerkLogger.warning(
        "Retrying \(operationName) after failure. Attempt \(attempt + 1) of \(policy.maxAttempts). Backing off for \(delayMs)ms."
      )
      try await Task.sleep(for: delay)
    }
  }
}

private func delayMilliseconds(_ duration: Duration) -> Int {
  let components = duration.components
  let seconds = Double(components.seconds)
  let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
  return Int(((seconds + attoseconds) * 1000).rounded())
}
