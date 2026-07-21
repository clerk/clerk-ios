import Foundation

/// Shared protocol for middleware that can intercept outgoing requests.
///
/// Provide implementations via ``Clerk/Options/middleware`` to run logic
/// immediately before a request is sent.
public protocol ClerkRequestMiddleware: Sendable {
  func prepare(_ request: inout URLRequest) async throws
}

/// Shared protocol for middleware that can validate incoming responses.
///
/// Provide implementations via ``Clerk/Options/middleware`` to run logic
/// immediately after a response is received.
public protocol ClerkResponseMiddleware: Sendable {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws
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
struct NetworkingPipeline {
  private let requestMiddleware: [any ClerkRequestMiddleware]
  private let customRequestMiddleware: [any ClerkRequestMiddleware]
  private let responseMiddleware: [any ClerkResponseMiddleware]
  private let retryMiddleware: [any NetworkRetryMiddleware]

  init(
    requestMiddleware: [any ClerkRequestMiddleware] = [],
    customRequestMiddleware: [any ClerkRequestMiddleware] = [],
    responseMiddleware: [any ClerkResponseMiddleware] = [],
    retryMiddleware: [any NetworkRetryMiddleware] = []
  ) {
    self.requestMiddleware = requestMiddleware
    self.customRequestMiddleware = customRequestMiddleware
    self.responseMiddleware = responseMiddleware
    self.retryMiddleware = retryMiddleware
  }

  func prepare(_ request: inout URLRequest) async throws {
    try await prepareClerkRequest(&request)
    try await prepareCustomRequest(&request)
  }

  func prepareClerkRequest(_ request: inout URLRequest) async throws {
    for middleware in requestMiddleware {
      try await middleware.prepare(&request)
    }
  }

  func prepareCustomRequest(_ request: inout URLRequest) async throws {
    for middleware in customRequestMiddleware {
      try await middleware.prepare(&request)
    }
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    for middleware in responseMiddleware {
      try await middleware.validate(response, data: data, for: request)
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
      requestMiddleware: requestMiddleware,
      customRequestMiddleware: customRequestMiddleware + middleware,
      responseMiddleware: responseMiddleware,
      retryMiddleware: retryMiddleware
    )
  }

  func appendingResponseMiddleware(_ middleware: [any ClerkResponseMiddleware]) -> NetworkingPipeline {
    NetworkingPipeline(
      requestMiddleware: requestMiddleware,
      customRequestMiddleware: customRequestMiddleware,
      responseMiddleware: middleware + responseMiddleware,
      retryMiddleware: retryMiddleware
    )
  }

  static func clerkDefault(
    runtimeScope: ClerkRuntimeScope
  ) -> NetworkingPipeline {
    NetworkingPipeline(
      requestMiddleware: [
        ClerkProxyRequestMiddleware(runtimeScope: runtimeScope),
        ClerkHeaderRequestMiddleware(runtimeScope: runtimeScope),
        ClerkQueryItemsRequestMiddleware(),
        ClerkURLEncodedFormEncoderMiddleware(),
        ClerkRequestLoggingMiddleware(),
      ],
      responseMiddleware: [
        ClerkResponseLoggingMiddleware(),
        ClerkClientSyncResponseMiddleware(runtimeScope: runtimeScope),
        ClerkAuthEventEmitterResponseMiddleware(runtimeScope: runtimeScope),
        ClerkInvalidAuthResponseMiddleware(runtimeScope: runtimeScope),
        ClerkErrorThrowingResponseMiddleware(),
      ],
      retryMiddleware: [
        ClerkRateLimitRetryMiddleware(),
      ]
    )
  }
}

extension HTTPURLResponse {
  private static let httpDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    return formatter
  }()

  var serverDate: Date? {
    guard let dateString = value(forHTTPHeaderField: "Date") else { return nil }
    return Self.httpDateFormatter.date(from: dateString)
  }
}

struct ClerkRequestCheckpoint: Equatable {
  let requestSequence: Int?
  let clientResponseGeneration: ClientResponseGeneration?
  let sharedSessionBaseGeneration: UInt64?
  let isCanonicalClientRequest: Bool
  let requestDeviceToken: String?

  init(
    requestSequence: Int?,
    clientResponseGeneration: ClientResponseGeneration?,
    sharedSessionBaseGeneration: UInt64?,
    isCanonicalClientRequest: Bool,
    requestDeviceToken: String?
  ) {
    self.requestSequence = requestSequence
    self.clientResponseGeneration = clientResponseGeneration
    self.sharedSessionBaseGeneration = sharedSessionBaseGeneration
    self.isCanonicalClientRequest = isCanonicalClientRequest
    self.requestDeviceToken = requestDeviceToken
  }

  init(request: URLRequest) {
    self.init(
      requestSequence: request.clerkRequestSequence,
      clientResponseGeneration: request.clerkClientResponseGeneration,
      sharedSessionBaseGeneration: request.clerkSharedSessionBaseGeneration,
      isCanonicalClientRequest: request.clerkIsCanonicalClientRequest,
      requestDeviceToken: request.clerkRequestDeviceToken
    )
  }

  func apply(to request: inout URLRequest) {
    request.setClerkRequestCheckpoint(self)
  }
}

extension URLRequest {
  private static let clerkRequestSequenceKey = "com.clerk.request-sequence"
  private static let clerkClientResponseGenerationKey = "com.clerk.client-response-generation"
  private static let clerkSharedSessionBaseGenerationKey = "com.clerk.shared-session-base-generation"
  private static let clerkCanonicalClientRequestKey = "com.clerk.canonical-client-request"
  private static let clerkRequestDeviceTokenKey = "com.clerk.request-device-token"
  private static let clerkCreatesClientWhenTokenlessKey = "com.clerk.creates-client-when-tokenless"

  var clerkRequestCheckpoint: ClerkRequestCheckpoint {
    ClerkRequestCheckpoint(request: self)
  }

  var clerkRequestSequence: Int? {
    URLProtocol.property(forKey: Self.clerkRequestSequenceKey, in: self) as? Int
  }

  var clerkClientResponseGeneration: ClientResponseGeneration? {
    ClientResponseGeneration(
      propertyListValue: URLProtocol.property(forKey: Self.clerkClientResponseGenerationKey, in: self)
    )
  }

  var clerkSharedSessionBaseGeneration: UInt64? {
    (URLProtocol.property(
      forKey: Self.clerkSharedSessionBaseGenerationKey,
      in: self
    ) as? NSNumber)?.uint64Value
  }

  var clerkIsCanonicalClientRequest: Bool {
    (URLProtocol.property(
      forKey: Self.clerkCanonicalClientRequestKey,
      in: self
    ) as? NSNumber)?.boolValue == true
  }

  var clerkRequestDeviceToken: String? {
    URLProtocol.property(forKey: Self.clerkRequestDeviceTokenKey, in: self) as? String
  }

  var clerkCreatesClientWhenTokenless: Bool {
    (URLProtocol.property(
      forKey: Self.clerkCreatesClientWhenTokenlessKey,
      in: self
    ) as? NSNumber)?.boolValue == true
  }

  mutating func setClerkRequestSequence(_ sequence: Int) {
    setClerkProperty(sequence, key: Self.clerkRequestSequenceKey)
  }

  mutating func setClerkClientResponseGeneration(_ generation: ClientResponseGeneration) {
    setClerkProperty(
      generation.propertyListValue,
      key: Self.clerkClientResponseGenerationKey
    )
  }

  mutating func setClerkSharedSessionBaseGeneration(_ generation: UInt64) {
    setClerkProperty(
      NSNumber(value: generation),
      key: Self.clerkSharedSessionBaseGenerationKey
    )
  }

  mutating func setClerkCanonicalClientRequest(_ isCanonical: Bool) {
    setClerkProperty(
      NSNumber(value: isCanonical),
      key: Self.clerkCanonicalClientRequestKey
    )
  }

  mutating func setClerkRequestDeviceToken(_ deviceToken: String) {
    setClerkProperty(deviceToken, key: Self.clerkRequestDeviceTokenKey)
  }

  mutating func setClerkCreatesClientWhenTokenless(_ createsClient: Bool) {
    setClerkProperty(
      createsClient ? NSNumber(value: true) : nil,
      key: Self.clerkCreatesClientWhenTokenlessKey
    )
  }

  mutating func setClerkRequestCheckpoint(_ checkpoint: ClerkRequestCheckpoint) {
    setClerkProperties([
      (value: checkpoint.requestSequence, key: Self.clerkRequestSequenceKey),
      (
        value: checkpoint.clientResponseGeneration?.propertyListValue,
        key: Self.clerkClientResponseGenerationKey
      ),
      (
        value: checkpoint.sharedSessionBaseGeneration.map { NSNumber(value: $0) },
        key: Self.clerkSharedSessionBaseGenerationKey
      ),
      (
        value: NSNumber(value: checkpoint.isCanonicalClientRequest),
        key: Self.clerkCanonicalClientRequestKey
      ),
      (value: checkpoint.requestDeviceToken, key: Self.clerkRequestDeviceTokenKey),
    ])
  }

  private mutating func setClerkProperty(_ value: Any?, key: String) {
    setClerkProperties([(value: value, key: key)])
  }

  private mutating func setClerkProperties(_ properties: [(value: Any?, key: String)]) {
    guard let mutableRequest = (self as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
      assertionFailure("Failed to create mutable URLRequest copy.")
      return
    }
    for (value, key) in properties {
      if let value {
        URLProtocol.setProperty(value, forKey: key, in: mutableRequest)
      } else {
        URLProtocol.removeProperty(forKey: key, in: mutableRequest)
      }
    }
    self = mutableRequest as URLRequest
  }
}
