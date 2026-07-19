import Foundation

/// Lightweight async API client that executes requests through the shared networking pipeline.
actor APIClient {
  private struct ClerkRequestContext: Equatable {
    let clientResponseGeneration: ClientResponseGeneration?
    let sharedSessionBaseGeneration: UInt64?
    let isCanonicalClientRequest: Bool
    let authorization: String?
    let clientID: String?

    init(request: URLRequest) {
      clientResponseGeneration = request.clerkClientResponseGeneration
      sharedSessionBaseGeneration = request.clerkSharedSessionBaseGeneration
      isCanonicalClientRequest = request.clerkIsCanonicalClientRequest
      authorization = request.value(forHTTPHeaderField: "Authorization")
      clientID = request.value(forHTTPHeaderField: "x-clerk-client-id")
    }

    func apply(to request: inout URLRequest) {
      if let clientResponseGeneration {
        request.setClerkClientResponseGeneration(clientResponseGeneration)
      }
      if let sharedSessionBaseGeneration {
        request.setClerkSharedSessionBaseGeneration(sharedSessionBaseGeneration)
      }
      request.setClerkCanonicalClientRequest(isCanonicalClientRequest)
      request.setValue(authorization, forHTTPHeaderField: "Authorization")
      request.setValue(clientID, forHTTPHeaderField: "x-clerk-client-id")
    }
  }

  struct Configuration {
    var sessionConfiguration: URLSessionConfiguration = {
      let configuration = URLSessionConfiguration.default
      configuration.httpAdditionalHeaders = [
        "Accept": "application/json",
      ]
      return configuration
    }()

    var encoder: JSONEncoder = .clerkEncoder
    var decoder: JSONDecoder = .clerkDecoder
    var pipeline: NetworkingPipeline

    init(runtimeScope: ClerkRuntimeScope) {
      pipeline = .clerkDefault(runtimeScope: runtimeScope)
    }
  }

  private let baseURL: URL?
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let pipeline: NetworkingPipeline
  private let runtimeScope: ClerkRuntimeScope
  private var nextRequestSequenceNumber = 0

  init(
    baseURL: URL?,
    runtimeScope: ClerkRuntimeScope,
    configure: @Sendable (inout Configuration) -> Void = { _ in }
  ) {
    var configuration = Configuration(runtimeScope: runtimeScope)
    configure(&configuration)

    self.baseURL = baseURL
    encoder = configuration.encoder
    decoder = configuration.decoder
    pipeline = configuration.pipeline
    self.runtimeScope = runtimeScope
    session = URLSession(configuration: configuration.sessionConfiguration)
  }

  @discardableResult
  func send<Value: Decodable & Sendable>(_ request: Request<Value>) async throws -> APIResponse<Value> {
    try await execute(request, uploadBody: nil)
  }

  @discardableResult
  func upload<Value: Decodable & Sendable>(
    for request: Request<Value>,
    from body: Data
  ) async throws -> APIResponse<Value> {
    try await execute(request, uploadBody: body)
  }

  private func execute<Value: Decodable & Sendable>(
    _ request: Request<Value>,
    uploadBody: Data?
  ) async throws -> APIResponse<Value> {
    var attempts = 0
    let requestSequence = makeRequestSequence()
    var clerkRequestContext: ClerkRequestContext?

    while true {
      try ensureCurrentRuntimeScope()
      attempts += 1

      var urlRequest = try request.makeURLRequest(baseURL: baseURL, encoder: encoder)
      urlRequest.setClerkRequestSequence(requestSequence)
      try await pipeline.prepareClerkRequest(&urlRequest)
      let preparedContext = ClerkRequestContext(request: urlRequest)
      if let clerkRequestContext {
        guard preparedContext == clerkRequestContext else {
          throw APIClientError.identityChangedBeforeRetry
        }
        clerkRequestContext.apply(to: &urlRequest)
      } else {
        clerkRequestContext = preparedContext
      }
      try await pipeline.prepareCustomRequest(&urlRequest)
      try ensureCurrentRuntimeScope()

      do {
        let data: Data
        let response: URLResponse

        if let uploadBody {
          (data, response) = try await session.upload(for: urlRequest, from: uploadBody)
        } else {
          (data, response) = try await session.data(for: urlRequest)
        }

        try ensureCurrentRuntimeScope()

        guard let httpResponse = response as? HTTPURLResponse else {
          throw APIClientError.invalidHTTPResponse
        }

        do {
          try await pipeline.validate(httpResponse, data: data, for: urlRequest)
          try ensureCurrentRuntimeScope()
        } catch {
          try ensureCurrentRuntimeScope()

          if try await pipeline.shouldRetry(
            request: urlRequest,
            response: httpResponse,
            error: error,
            attempts: attempts
          ) {
            continue
          }
          throw error
        }

        let value = try request.decode(data, using: decoder)
        try ensureCurrentRuntimeScope()
        return APIResponse(value: value, requestSequence: requestSequence, serverDate: httpResponse.serverDate)
      } catch {
        try ensureCurrentRuntimeScope()

        if try await pipeline.shouldRetry(
          request: urlRequest,
          response: nil,
          error: error,
          attempts: attempts
        ) {
          continue
        }
        throw error
      }
    }
  }

  private func makeRequestSequence() -> Int {
    nextRequestSequenceNumber += 1
    return nextRequestSequenceNumber
  }

  private func ensureCurrentRuntimeScope() throws {
    try runtimeScope.validateStableRuntime()
  }
}

enum APIClientError: Error {
  case invalidHTTPResponse
  case identityChangedBeforeRetry
}
