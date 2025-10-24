import Foundation

/// Shared protocol for middleware that can intercept outgoing requests.
protocol NetworkRequestMiddleware: Sendable {
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
  private let requestMiddleware: [any NetworkRequestMiddleware]
  private let responseMiddleware: [any NetworkResponseMiddleware]
  private let retryMiddleware: [any NetworkRetryMiddleware]

  init(
    requestMiddleware: [any NetworkRequestMiddleware] = [],
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
    for middleware in retryMiddleware {
      if try await middleware.shouldRetry(request: request, response: response, error: error, attempts: attempts) {
        return true
      }
    }
    return false
  }
}

extension NetworkingPipeline {
  static var clerkDefault: NetworkingPipeline {
    NetworkingPipeline(
      requestMiddleware: [
        ClerkProxyRequestMiddleware(),
        ClerkHeaderRequestMiddleware(),
        ClerkQueryItemsRequestMiddleware(),
        ClerkURLEncodedFormEncoderMiddleware(),
        ClerkRequestLoggingMiddleware()
      ],
      responseMiddleware: [
        ClerkResponseLoggingMiddleware(),
        ClerkDeviceTokenResponseMiddleware(),
        ClerkClientSyncResponseMiddleware(),
        ClerkAuthEventEmitterResponseMiddleware(),
        ClerkInvalidAuthResponseMiddleware(),
        ClerkErrorThrowingResponseMiddleware()
      ],
      retryMiddleware: [
        ClerkDeviceAssertionRetryMiddleware(),
        ClerkRateLimitRetryMiddleware()
      ]
    )
  }
}

// TODO: add tests ensuring middleware order and error handling using MockingURLProtocol.
