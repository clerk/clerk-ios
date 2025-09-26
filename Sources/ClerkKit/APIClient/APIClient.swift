import Foundation

// MARK: - Supporting Types

struct AnyEncodable: Encodable, Sendable {
    private let encodeClosure: @Sendable (Encoder) throws -> Void

    init<T: Encodable & Sendable>(_ value: T) {
        encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

struct NoContent: Codable, Sendable {
    init() {}

    init(from decoder: Decoder) throws {
        self.init()
    }

    func encode(to encoder: Encoder) throws {}
}

/// Context shared across middleware stages while processing a network request.
struct RequestPipelineContext: Sendable {
    /// The final request submitted to the underlying URLSession.
    let request: URLRequest
    /// The current retry attempt (starting at 1).
    let attempt: Int
}

protocol RequestPreprocessor: Sendable {
    static func process(request: inout URLRequest) async throws
}

protocol RequestPostprocessor: Sendable {
    static func process(response: HTTPURLResponse, data: Data, context: RequestPipelineContext) throws
}

protocol RequestRetrier: Sendable {
    static func retryDecision(context: RequestPipelineContext, error: any Error, attempts: Int) async throws -> RetryDecision
}

enum APIClientError: Error, LocalizedError {
    case missingBaseURL
    case invalidURLComponents
    case invalidHTTPResponse

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "APIClient base URL is not configured."
        case .invalidURLComponents:
            return "Failed to construct a valid request URL."
        case .invalidHTTPResponse:
            return "Received an invalid HTTPURLResponse."
        }
    }
}

protocol APIClientProtocol: Sendable {
    @discardableResult
    func send<Response>(_ request: Request<Response>) async throws -> NetworkResponse<Response>

    @discardableResult
    func upload<Response>(_ request: Request<Response>, from data: Data) async throws -> NetworkResponse<Response>
}

struct NetworkResponse<Value: Sendable>: Sendable {
    let value: Value
    let response: HTTPURLResponse
    let data: Data
}

enum RetryDecision: Sendable {
    case retry(after: Duration? = nil)
    case doNotRetry
}

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let delay: @Sendable (Int) -> Duration?

    init(maxAttempts: Int = 1, delay: @escaping @Sendable (Int) -> Duration? = { _ in nil }) {
        self.maxAttempts = max(1, maxAttempts)
        self.delay = delay
    }
}


struct HTTPMethod: RawRepresentable, Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let get: HTTPMethod = "GET"
    public static let post: HTTPMethod = "POST"
    public static let patch: HTTPMethod = "PATCH"
    public static let put: HTTPMethod = "PUT"
    public static let delete: HTTPMethod = "DELETE"
    public static let options: HTTPMethod = "OPTIONS"
    public static let head: HTTPMethod = "HEAD"
    public static let trace: HTTPMethod = "TRACE"
}

struct Request<Response: Decodable & Sendable>: Sendable {
    struct Body: Sendable {
        enum Storage: Sendable {
            case data(Data)
            case encodable(AnyEncodable)
        }

        let storage: Storage

        static func data(_ data: Data) -> Body {
            Body(storage: .data(data))
        }

        static func encodable(_ value: AnyEncodable) -> Body {
            Body(storage: .encodable(value))
        }
    }

    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Body?
    let encoder: JSONEncoder?
    let decoder: JSONDecoder?
    let retryPolicy: RetryPolicy?

    static func build(
        path: String,
        configure: (inout RequestBuilder<Response>) -> Void = { _ in }
    ) -> Request<Response> {
        var builder = RequestBuilder<Response>(path: path)
        configure(&builder)
        return builder.build()
    }
}

struct RequestBuilder<Response: Decodable & Sendable> {
    private var path: String
    private var method: HTTPMethod = .get
    private var headers: [String: String] = [:]
    private var queryItems: [URLQueryItem] = []
    private var body: Request<Response>.Body?
    private var encoder: JSONEncoder?
    private var decoder: JSONDecoder?
    private var retryPolicy: RetryPolicy?

    init(path: String) {
        self.path = path
    }

    mutating func method(_ method: HTTPMethod) {
        self.method = method
    }

    mutating func headers(_ headers: [String: String]) {
        for (key, value) in headers {
            self.headers[key] = value
        }
    }

    mutating func header(_ name: String, value: String?) {
        self.headers[name] = value
    }

    mutating func queryItems(_ items: [(String, String?)]) {
        queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
    }

    mutating func appendQueryItem(name: String, value: String?) {
        queryItems.append(URLQueryItem(name: name, value: value))
    }

    mutating func body<T: Encodable & Sendable>(_ value: T) {
        self.body = .encodable(AnyEncodable(value))
    }

    mutating func rawBody(_ data: Data) {
        self.body = .data(data)
    }

    mutating func encoder(_ encoder: JSONEncoder) {
        self.encoder = encoder
    }

    mutating func decoder(_ decoder: JSONDecoder) {
        self.decoder = decoder
    }

    mutating func retryPolicy(_ policy: RetryPolicy) {
        self.retryPolicy = policy
    }

    func build() -> Request<Response> {
        Request(
            path: path,
            method: method,
            headers: headers,
            queryItems: queryItems,
            body: body,
            encoder: encoder,
            decoder: decoder,
            retryPolicy: retryPolicy
        )
    }
}

extension RequestBuilder {
    mutating func appendSessionIdQuery() {
        appendQueryItem(name: "_clerk_session_id", value: Clerk.shared.session?.id)
    }
}

actor APIClient: APIClientProtocol {
    struct Configuration {
        var baseURL: URL?
        var sessionConfiguration: URLSessionConfiguration
        var defaultHeaders: [String: String]
        var encoder: JSONEncoder
        var decoder: JSONDecoder
        var preprocessors: [RequestPreprocessor.Type]
        var postprocessors: [RequestPostprocessor.Type]
        var retriers: [RequestRetrier.Type]
        var retryPolicy: RetryPolicy

        init(
            baseURL: URL? = nil,
            sessionConfiguration: URLSessionConfiguration = .default,
            defaultHeaders: [String: String] = [:],
            encoder: JSONEncoder = .init(),
            decoder: JSONDecoder = .init(),
            preprocessors: [RequestPreprocessor.Type] = [],
            postprocessors: [RequestPostprocessor.Type] = [],
            retriers: [RequestRetrier.Type] = [],
            retryPolicy: RetryPolicy = .init()
        ) {
            self.baseURL = baseURL
            self.sessionConfiguration = sessionConfiguration
            self.defaultHeaders = defaultHeaders
            self.encoder = encoder
            self.decoder = decoder
            self.preprocessors = preprocessors
            self.postprocessors = postprocessors
            self.retriers = retriers
            self.retryPolicy = retryPolicy
        }
    }

    private var configuration: Configuration
    private let session: URLSession

    init(baseURL: URL? = nil, configure: (inout Configuration) -> Void = { _ in }) {
        var configuration = Configuration(baseURL: baseURL)
        configure(&configuration)
        self.configuration = configuration
        self.session = URLSession(configuration: configuration.sessionConfiguration)
    }

    @discardableResult
    func send<Response>(_ request: Request<Response>) async throws -> NetworkResponse<Response> {
        try await perform(request, uploadBody: nil)
    }

    @discardableResult
    func upload<Response>(_ request: Request<Response>, from data: Data) async throws -> NetworkResponse<Response> {
        try await perform(request, uploadBody: data)
    }

    private func perform<Response>(_ request: Request<Response>, uploadBody: Data?) async throws -> NetworkResponse<Response> {
        var attempt = 1
        let policy = request.retryPolicy ?? configuration.retryPolicy

        while true {
            var urlRequest = try makeURLRequest(from: request, uploadBody: uploadBody)
            try await applyPreprocessors(to: &urlRequest)
            let context = RequestPipelineContext(request: urlRequest, attempt: attempt)

            do {
                let (data, response) = try await execute(urlRequest, uploadBody: uploadBody)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIClientError.invalidHTTPResponse
                }

                try applyPostprocessors(response: httpResponse, data: data, context: context)
                let value = try decode(Response.self, from: data, using: request)

                return NetworkResponse(value: value, response: httpResponse, data: data)
            } catch {
                switch try await retryDecision(for: context, error: error, attempt: attempt, policy: policy) {
                case .retry(let delay):
                    attempt += 1
                    if let delay {
                        try await Task.sleep(for: delay)
                    }
                    continue
                case .doNotRetry:
                    throw error
                }
            }
        }
    }

    private func makeURLRequest<Response>(from request: Request<Response>, uploadBody: Data?) throws -> URLRequest {
        let url = try makeURL(for: request)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        var headers = configuration.defaultHeaders
        for (key, value) in request.headers {
            headers[key] = value
        }
        urlRequest.allHTTPHeaderFields = headers

        if let body = request.body {
            urlRequest.httpBody = try encodeBody(body, for: request)
        } else if let uploadBody {
            urlRequest.httpBody = uploadBody
        }

        return urlRequest
    }

    private func makeURL<Response>(for request: Request<Response>) throws -> URL {
        if let absolute = URL(string: request.path), absolute.scheme != nil {
            return try appendQueryItems(request.queryItems, to: absolute)
        }

        guard let baseURL = configuration.baseURL else {
            throw APIClientError.missingBaseURL
        }

        guard let combined = URL(string: request.path, relativeTo: baseURL) else {
            throw APIClientError.invalidURLComponents
        }

        return try appendQueryItems(request.queryItems, to: combined.absoluteURL)
    }

    private func appendQueryItems(_ items: [URLQueryItem], to url: URL) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidURLComponents
        }
        let existing = components.queryItems ?? []
        components.queryItems = mergeQueryItems(existing, items)
        guard let finalURL = components.url else {
            throw APIClientError.invalidURLComponents
        }
        return finalURL
    }

    private func mergeQueryItems(_ existing: [URLQueryItem], _ additional: [URLQueryItem]) -> [URLQueryItem]? {
        let combined = existing + additional
        return combined.isEmpty ? nil : combined
    }

    private func encodeBody<Response>(_ body: Request<Response>.Body, for request: Request<Response>) throws -> Data {
        switch body.storage {
        case .data(let data):
            return data
        case .encodable(let encodable):
            let encoder = request.encoder ?? configuration.encoder
            return try encoder.encode(encodable)
        }
    }

    private func execute(_ request: URLRequest, uploadBody: Data?) async throws -> (Data, URLResponse) {
        if let uploadBody {
            return try await session.upload(for: request, from: uploadBody)
        } else {
            return try await session.data(for: request)
        }
    }

    private func applyPreprocessors(to request: inout URLRequest) async throws {
        for preprocessor in configuration.preprocessors {
            try await preprocessor.process(request: &request)
        }
    }

    private func applyPostprocessors(response: HTTPURLResponse, data: Data, context: RequestPipelineContext) throws {
        for postprocessor in configuration.postprocessors {
            try postprocessor.process(response: response, data: data, context: context)
        }
    }

    private func retryDecision(for context: RequestPipelineContext, error: any Error, attempt: Int, policy: RetryPolicy) async throws -> RetryDecision {
        for retrier in configuration.retriers {
            let decision = try await retrier.retryDecision(context: context, error: error, attempts: attempt)
            if case .retry = decision {
                return decision
            }
        }

        guard attempt < policy.maxAttempts else {
            return .doNotRetry
        }

        return .retry(after: policy.delay(attempt + 1))
    }

    private func decode<Response>(_ type: Response.Type, from data: Data, using request: Request<Response>) throws -> Response {
        if Response.self == NoContent.self {
            return NoContent() as! Response
        }

        let decoder = request.decoder ?? configuration.decoder
        return try decoder.decode(Response.self, from: data)
    }
}
