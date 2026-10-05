//
//  ClerkRateLimitRetryMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkRateLimitRetryMiddleware: NetworkRetryMiddleware {
  private let sleep: @Sendable (UInt64) async -> Void
  private let currentDate: @Sendable () -> Date

  init(
    sleep: @escaping @Sendable (UInt64) async -> Void = { nanos in
      try? await Task.sleep(nanoseconds: nanos)
    },
    currentDate: @escaping @Sendable () -> Date = { .now }
  ) {
    self.sleep = sleep
    self.currentDate = currentDate
  }

  func shouldRetry(
    request: URLRequest,
    response: HTTPURLResponse?,
    error: any Error,
    attempts: Int
  ) async throws -> Bool {
    guard attempts == 1 else { return false }

    // A 5xx, timeout, or dropped connection can arrive after the server already
    // processed the request, so only safe methods retry on those signals.
    let isSafeMethod = Self.safeMethods.contains(request.httpMethod ?? "GET")

    if let response,
       shouldRetry(statusCode: response.statusCode, isSafeMethod: isSafeMethod)
    {
      let delay = retryDelay(for: response)
      await sleep(delay)
      await logRetry(
        reason: "HTTP \(response.statusCode)",
        request: request,
        delay: delay
      )
      return true
    }

    if let urlError = error as? URLError {
      if shouldRetry(urlError: urlError, isSafeMethod: isSafeMethod) {
        let delay = defaultBackoffDelay()
        await sleep(delay)
        await logRetry(
          reason: "URLError \(urlError.code.rawValue)",
          request: request,
          delay: delay
        )
        return true
      }
    }

    return false
  }

  // MARK: - Helpers

  private static let safeMethods: Set<String> = ["GET", "HEAD"]

  private func shouldRetry(statusCode: Int, isSafeMethod: Bool) -> Bool {
    switch statusCode {
    case 408, 425, 429:
      true
    case 500, 502, 503, 504:
      isSafeMethod
    default:
      false
    }
  }

  private func shouldRetry(urlError: URLError, isSafeMethod: Bool) -> Bool {
    switch urlError.code {
    case .cannotFindHost,
         .cannotConnectToHost,
         .dnsLookupFailed,
         .notConnectedToInternet:
      true
    case .timedOut,
         .networkConnectionLost:
      isSafeMethod
    default:
      false
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
      let interval = date.timeIntervalSince(currentDate())
      guard interval > 0 else { return nil }
      return nanosecondsFrom(seconds: interval)
    }

    return nil
  }

  private func retryDelayFromReset(_ value: String) -> UInt64? {
    guard let resetInterval = TimeInterval(value) else { return nil }
    let interval = resetInterval - currentDate().timeIntervalSince1970
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
    let url = request?.url?.absoluteString ?? "<unknown url>"
    let delayMs = Double(delay) / 1_000_000
    let formattedDelay = String(format: "%.0f", delayMs)
    ClerkLogger.info(
      "Retrying request: \(url) after \(reason). Backing off for \(formattedDelay)ms."
    )
  }
}
