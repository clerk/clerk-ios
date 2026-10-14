import Foundation

package enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"
}

/// Type-erased `Encodable` wrapper used to defer encoding until the request is sent.
struct AnyEncodable: Encodable, @unchecked Sendable {
  private let encodeClosure: @Sendable (Encoder) throws -> Void

  init(_ base: some Encodable & Sendable) {
    encodeClosure = { encoder in
      try base.encode(to: encoder)
    }
  }

  func encode(to encoder: Encoder) throws {
    try encodeClosure(encoder)
  }
}

struct EncodableDictionary: Encodable, @unchecked Sendable {
  let dictionary: [String: Any]

  init(_ dictionary: [String: Any]) {
    self.dictionary = dictionary
  }

  func encode(to encoder: Encoder) throws {
    let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
    let json = try JSONDecoder().decode(JSON.self, from: jsonData)
    try json.encode(to: encoder)
  }
}

enum RequestBody: @unchecked Sendable {
  case data(Data)
  case encodable(AnyEncodable)

  func encoded(using encoder: JSONEncoder) throws -> Data {
    switch self {
    case let .data(data):
      data
    case let .encodable(value):
      try encoder.encode(value)
    }
  }
}

struct EmptyResponse: Codable {}

package struct Request<Response: Decodable & Sendable> {
  let path: String
  let method: HTTPMethod
  let headers: [String: String]
  let canEstablishClientWhenTokenless: Bool

  private let scopedToActiveSession: Bool
  private let queryItems: [URLQueryItem]
  private let body: RequestBody?
  private let automaticallySyncClient: Bool
  private let logBodies: Bool
  private let decodeClosure: @Sendable (Data, JSONDecoder) throws -> Response

  init(
    path: String,
    method: HTTPMethod = .get,
    headers: [String: String] = [:],
    canEstablishClientWhenTokenless: Bool = false,
    scopedToActiveSession: Bool = false,
    query: [(String, String?)] = [],
    body: (any Encodable & Sendable)? = nil,
    automaticallySyncClient: Bool = true,
    logBodies: Bool = true,
    decode: @escaping @Sendable (Data, JSONDecoder) throws -> Response = { data, decoder in
      if Response.self == EmptyResponse.self {
        guard let response = EmptyResponse() as? Response else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Failed to cast EmptyResponse to Response")
          )
        }
        return response
      }
      return try decoder.decode(Response.self, from: data)
    }
  ) {
    self.path = path
    self.method = method
    self.headers = headers
    self.canEstablishClientWhenTokenless = canEstablishClientWhenTokenless
    self.scopedToActiveSession = scopedToActiveSession
    queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
    self.body = body.map { .encodable(AnyEncodable($0)) }
    self.automaticallySyncClient = automaticallySyncClient
    self.logBodies = logBodies
    decodeClosure = decode
  }

  func makeURLRequest(baseURL: URL?, encoder: JSONEncoder) throws -> URLRequest {
    let resolvedURL: URL

    if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
      resolvedURL = absoluteURL
    } else {
      guard let baseURL else {
        throw RequestError.missingBaseURL(path: path)
      }

      let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
      resolvedURL = baseURL.appendingPathComponent(trimmedPath)
    }

    guard var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) else {
      throw RequestError.invalidURL(path: resolvedURL.absoluteString)
    }

    if !queryItems.isEmpty {
      let existing = components.queryItems ?? []
      components.queryItems = existing + queryItems
    }

    guard let finalURL = components.url else {
      throw RequestError.invalidURL(path: resolvedURL.absoluteString)
    }

    var urlRequest = URLRequest(url: finalURL)
    urlRequest.httpMethod = method.rawValue
    if !headers.isEmpty {
      var headerFields = urlRequest.allHTTPHeaderFields ?? [:]
      headers.forEach { headerFields[$0.key] = $0.value }
      urlRequest.allHTTPHeaderFields = headerFields
    }

    if let bodyData = try body?.encoded(using: encoder) {
      urlRequest.httpBody = bodyData

      let hasContentTypeHeader = urlRequest
        .allHTTPHeaderFields?
        .keys
        .contains { $0.caseInsensitiveCompare("Content-Type") == .orderedSame } ?? false

      if !hasContentTypeHeader {
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      }
    }

    applyPipelineFlags(to: &urlRequest)

    return urlRequest
  }

  private func applyPipelineFlags(to urlRequest: inout URLRequest) {
    if scopedToActiveSession {
      urlRequest.scopeToClerkActiveSession()
    }
    if !automaticallySyncClient {
      urlRequest.disableAutomaticClerkClientSync()
    }
    if !logBodies {
      urlRequest.disableClerkBodyLogging()
    }
  }

  func decode(_ data: Data, using decoder: JSONDecoder) throws -> Response {
    if Response.self == EmptyResponse.self {
      guard let response = EmptyResponse() as? Response else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(codingPath: [], debugDescription: "Failed to cast EmptyResponse to Response")
        )
      }
      return response
    }
    return try decodeClosure(data, decoder)
  }
}

enum RequestError: Error {
  case missingBaseURL(path: String)
  case invalidURL(path: String)
}

struct APIResponse<Value: Sendable> {
  let value: Value
  let requestSequence: Int?
  let serverDate: Date?
  let deferredClientSyncMetadata: ClientSyncResponseMetadata?
}
