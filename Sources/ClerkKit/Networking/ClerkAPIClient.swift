import Foundation

/// Lightweight async API client that executes requests through the shared networking pipeline.
actor APIClient {
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
    var pipeline: NetworkingPipeline = .clerkDefault
  }

  private let baseURL: URL?
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let pipeline: NetworkingPipeline
  /// Monotonic ordering token for responses produced by this API client instance.
  ///
  /// This sequence space is intentionally independent from Clerk's runtime client
  /// response watermark and cache persistence sequencing.
  private var requestSequenceCounter: UInt64 = 0

  init(baseURL: URL?, configure: (inout Configuration) -> Void = { _ in }) {
    var configuration = Configuration()
    configure(&configuration)

    self.baseURL = baseURL
    encoder = configuration.encoder
    decoder = configuration.decoder
    pipeline = configuration.pipeline
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
    let requestSequence = nextRequestSequence()

    while true {
      attempts += 1

      var urlRequest = try request.makeURLRequest(baseURL: baseURL, encoder: encoder)
      try await pipeline.prepare(&urlRequest)
      // Stamp sequencing/sync metadata after request middleware runs so middleware
      // cannot accidentally drop the metadata by rebuilding the URLRequest.
      urlRequest.setRequestSequence(requestSequence)
      urlRequest.setClientSyncDirective(request.clientSyncDirective)

      do {
        let data: Data
        let response: URLResponse

        if let uploadBody {
          (data, response) = try await session.upload(for: urlRequest, from: uploadBody)
        } else {
          (data, response) = try await session.data(for: urlRequest)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
          throw APIClientError.invalidHTTPResponse
        }

        do {
          try await pipeline.validate(httpResponse, data: data, for: urlRequest)
        } catch {
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
        return APIResponse(value: value, requestSequence: requestSequence)
      } catch {
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

  private func nextRequestSequence() -> UInt64 {
    requestSequenceCounter &+= 1
    return requestSequenceCounter
  }
}

enum APIClientError: Error {
  case invalidHTTPResponse
}
