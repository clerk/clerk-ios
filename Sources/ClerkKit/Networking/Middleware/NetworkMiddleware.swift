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
