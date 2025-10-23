import Foundation

/// Shared protocol for middleware that can intercept outgoing requests.
protocol NetworkRequestMiddleware: Sendable {
  func prepare(_ request: inout URLRequest) async throws
}

/// Shared protocol for middleware that can validate responses.
protocol NetworkResponseMiddleware: Sendable {
  func validate(_ response: HTTPURLResponse, data: Data, task: URLSessionTask) throws
}

/// Allows middleware to influence retry decisions.
protocol NetworkRetryMiddleware: Sendable {
  func shouldRetry(_ task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool
}

// TODO: define concrete middleware types (e.g., AuthHeaderMiddleware, LoggingMiddleware, RetryMiddleware).
// TODO: add tests ensuring middleware order and error handling using MockingURLProtocol.

// TODO: create NetworkingPipeline type that composes request/response/retry middleware.
// TODO: expose APIClient extension to register middleware pipeline.
