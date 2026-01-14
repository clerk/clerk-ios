import Foundation

/// Shared protocol for middleware that can intercept outgoing requests.
///
/// Provide implementations via ``Clerk/ClerkOptions/requestMiddleware`` to run logic
/// immediately before a request is sent.
public protocol ClerkRequestMiddleware: Sendable {
  func prepare(_ request: inout URLRequest) async throws
}

/// Shared protocol for middleware that can validate responses.
protocol NetworkResponseMiddleware: Sendable {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws
}

/// Allows middleware to influence retry decisions.
protocol NetworkRetryMiddleware: Sendable {
  func shouldRetry(
    request: URLRequest,
    response: HTTPURLResponse?,
    error: any Error,
    attempts: Int
  ) async throws -> Bool
}

/// Describes the order of execution for networking middleware.
struct NetworkingPipeline: Sendable {
  private let requestMiddleware: [any ClerkRequestMiddleware]
  private let responseMiddleware: [any NetworkResponseMiddleware]
  private let retryMiddleware: [any NetworkRetryMiddleware]

  init(
    requestMiddleware: [any ClerkRequestMiddleware] = [],
    responseMiddleware: [any NetworkResponseMiddleware] = [],
    retryMiddleware: [any NetworkRetryMiddleware] = []
  ) {
    self.requestMiddleware = requestMiddleware
    self.responseMiddleware = responseMiddleware
    self.retryMiddleware = retryMiddleware
  }

  func prepare(_ request: inout URLRequest) async throws {
    for middleware in requestMiddleware {
      try await middleware.prepare(&request)
    }
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
    for middleware in responseMiddleware {
      try middleware.validate(response, data: data, for: request)
    }
  }

  func shouldRetry(
    request: URLRequest,
    response: HTTPURLResponse?,
    error: any Error,
    attempts: Int
  ) async throws -> Bool {
    for middleware in retryMiddleware where try await middleware.shouldRetry(request: request, response: response, error: error, attempts: attempts) {
      return true
    }
    return false
  }
}

extension NetworkingPipeline {
  func appendingRequestMiddleware(_ middleware: [any ClerkRequestMiddleware]) -> NetworkingPipeline {
    NetworkingPipeline(
      requestMiddleware: requestMiddleware + middleware,
      responseMiddleware: responseMiddleware,
      retryMiddleware: retryMiddleware
    )
  }

  static var clerkDefault: NetworkingPipeline {
    NetworkingPipeline(
      requestMiddleware: [
        ClerkProxyRequestMiddleware(),
        ClerkHeaderRequestMiddleware(),
        ClerkQueryItemsRequestMiddleware(),
        ClerkURLEncodedFormEncoderMiddleware(),
        ClerkRequestLoggingMiddleware(),
      ],
      responseMiddleware: [
        ClerkResponseLoggingMiddleware(),
        ClerkDeviceTokenResponseMiddleware(),
        ClerkClientSyncResponseMiddleware(),
        ClerkAuthEventEmitterResponseMiddleware(),
        ClerkInvalidAuthResponseMiddleware(),
        ClerkErrorThrowingResponseMiddleware(),
      ],
      retryMiddleware: [
        ClerkDeviceAssertionRetryMiddleware(),
        ClerkRateLimitRetryMiddleware(),
      ]
    )
  }
}
