//
//  ClerkRateLimitRetryMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 10/23/25.
//

import Foundation

/// Handles retry/backoff decisions for rate limit and transient networking errors.
struct ClerkRateLimitRetryMiddleware: NetworkRetryMiddleware {
  private let sleep: @Sendable (UInt64) async -> Void

  init(
    sleep: @escaping @Sendable (UInt64) async -> Void = { nanos in
      try? await Task.sleep(nanoseconds: nanos)
    }
  ) {
    self.sleep = sleep
  }

  func shouldRetry(_ task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool {
    guard attempts == 1 else { return false }

    if let response = task.response as? HTTPURLResponse,
       shouldRetry(statusCode: response.statusCode)
    {
      let delay = retryDelay(for: response)
      await sleep(delay)
      await logRetry(
        reason: "HTTP \(response.statusCode)",
        request: task.originalRequest,
        delay: delay
      )
      return true
    }

    if let urlError = error as? URLError,
       shouldRetry(urlError: urlError)
    {
      let delay = defaultBackoffDelay()
      await sleep(delay)
      await logRetry(
        reason: "URLError \(urlError.code.rawValue)",
        request: task.originalRequest,
        delay: delay
      )
      return true
    }

    return false
  }

  // MARK: - Helpers

  private func shouldRetry(statusCode: Int) -> Bool {
    switch statusCode {
    case 408, 425, 429, 500, 502, 503, 504:
      return true
    default:
      return false
    }
  }

  private func shouldRetry(urlError: URLError) -> Bool {
    switch urlError.code {
    case .timedOut,
         .cannotFindHost,
         .cannotConnectToHost,
         .networkConnectionLost,
         .dnsLookupFailed,
         .notConnectedToInternet:
      return true
    default:
      return false
    }
  }

  private func retryDelay(for response: HTTPURLResponse) -> UInt64 {
    if let header = response.value(forHTTPHeaderField: "Retry-After"),
       let fromHeader = retryDelayFromRetryAfter(header)
    {
      return fromHeader
    }

    if let header = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
       let fromReset = retryDelayFromReset(header)
    {
      return fromReset
    }

    return defaultBackoffDelay()
  }

  private func retryDelayFromRetryAfter(_ value: String) -> UInt64? {
    if let seconds = TimeInterval(value) {
      return nanosecondsFrom(seconds: seconds)
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "E',' dd MMM yyyy HH':'mm':'ss zzz"

    if let date = formatter.date(from: value) {
      let interval = date.timeIntervalSinceNow
      guard interval > 0 else { return nil }
      return nanosecondsFrom(seconds: interval)
    }

    return nil
  }

  private func retryDelayFromReset(_ value: String) -> UInt64? {
    guard let resetInterval = TimeInterval(value) else { return nil }
    let interval = resetInterval - Date().timeIntervalSince1970
    guard interval > 0 else { return nil }
    return nanosecondsFrom(seconds: interval)
  }

  private func defaultBackoffDelay() -> UInt64 {
    nanosecondsFrom(seconds: 0.5)
  }

  private func nanosecondsFrom(seconds: TimeInterval) -> UInt64 {
    let clamped = min(max(seconds, 0.1), 5.0)
    return UInt64(clamped * 1_000_000_000)
  }

  @MainActor
  private func logRetry(reason: String, request: URLRequest?, delay: UInt64) {
    guard Clerk.shared.settings.debugMode else { return }

    let url = request?.url?.absoluteString ?? "<unknown url>"
    let delayMs = Double(delay) / 1_000_000
    let formattedDelay = String(format: "%.0f", delayMs)
    ClerkLogger.debug(
      "Retrying request: \(url) after \(reason). Backing off for \(formattedDelay)ms.",
      debugMode: true
    )
  }
}
