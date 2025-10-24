import Foundation

/// Supported HTTP verbs for Clerk network requests.
enum HTTPMethod: String, Sendable {
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
    self.encodeClosure = { encoder in
      try base.encode(to: encoder)
    }
  }

  func encode(to encoder: Encoder) throws {
    try encodeClosure(encoder)
  }
}

/// Represents a request body, either unused, raw data, or an encodable payload.
enum RequestBody: @unchecked Sendable {
  case data(Data)
  case encodable(AnyEncodable)

  func encoded(using encoder: JSONEncoder) throws -> Data {
    switch self {
    case let .data(data):
      return data
    case let .encodable(value):
      return try encoder.encode(value)
    }
  }
}

/// Canonical empty payload used for requests where no response body is anticipated.
struct EmptyResponse: Codable, Sendable {
  init() {}
}

/// Describes a single API request with a strongly typed response.
struct Request<Response: Decodable & Sendable>: Sendable {
  let path: String
  let method: HTTPMethod
  let headers: [String: String]

  private let queryItems: [URLQueryItem]
  private let body: RequestBody?
  private let decodeClosure: @Sendable (Data, JSONDecoder) throws -> Response

  init(
    path: String,
    method: HTTPMethod = .get,
    headers: [String: String] = [:],
    query: [(String, String?)] = [],
    body: (any Encodable & Sendable)? = nil,
    decode: @escaping @Sendable (Data, JSONDecoder) throws -> Response = { data, decoder in
      if Response.self == EmptyResponse.self {
        return EmptyResponse() as! Response
      }
      return try decoder.decode(Response.self, from: data)
    }
  ) {
    self.path = path
    self.method = method
    self.headers = headers
    self.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
    self.body = body.map { .encodable(AnyEncodable($0)) }
    self.decodeClosure = decode
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
    }

    return urlRequest
  }

  func decode(_ data: Data, using decoder: JSONDecoder) throws -> Response {
    if Response.self == EmptyResponse.self {
      return EmptyResponse() as! Response
    }
    return try decodeClosure(data, decoder)
  }
}

enum RequestError: Error {
  case missingBaseURL(path: String)
  case invalidURL(path: String)
}

/// Wraps a decoded response value from the API client.
struct APIResponse<Value: Sendable>: Sendable {
  let value: Value
}
