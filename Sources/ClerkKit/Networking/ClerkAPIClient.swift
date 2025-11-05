import Foundation

/// Lightweight async API client that executes requests through the shared networking pipeline.
actor APIClient {
  struct Configuration {
    var sessionConfiguration: URLSessionConfiguration = {
      let configuration = URLSessionConfiguration.default
      configuration.httpAdditionalHeaders = [
        "Accept": "application/json"
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

  init(baseURL: URL?, configure: (inout Configuration) -> Void = { _ in }) {
    var configuration = Configuration()
    configure(&configuration)

    self.baseURL = baseURL
    self.encoder = configuration.encoder
    self.decoder = configuration.decoder
    self.pipeline = configuration.pipeline
    self.session = URLSession(configuration: configuration.sessionConfiguration)
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

    while true {
      attempts += 1

      var urlRequest = try request.makeURLRequest(baseURL: baseURL, encoder: encoder)
      try await pipeline.prepare(&urlRequest)

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
          try pipeline.validate(httpResponse, data: data, for: urlRequest)
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
        return APIResponse(value: value)
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
}

enum APIClientError: Error {
  case invalidHTTPResponse
}
