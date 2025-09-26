import Foundation

@_spi(Internal)
public final actor MockAPIClient {

    struct RequestContext: Sendable, Equatable {
        let method: HTTPMethod
        let path: String
        let normalizedPath: String
        let headers: [String: String]
        let queryItems: [URLQueryItem]
        let body: Data?

        init(
            method: HTTPMethod,
            path: String,
            headers: [String: String],
            queryItems: [URLQueryItem],
            body: Data?
        ) {
            self.method = method
            self.path = path
            self.normalizedPath = MockAPIClient.normalize(path)
            self.headers = headers
            self.queryItems = queryItems
            self.body = body
        }
    }

    enum Error: Swift.Error, CustomNSError, LocalizedError {
        case unhandledRequest(RequestContext)

        public var errorCode: Int { 0 }

        public var errorUserInfo: [String: Any] {
            switch self {
            case .unhandledRequest(let context):
                return [NSLocalizedDescriptionKey: "No mock response registered for \(context.method.rawValue) \(context.path)"]
            }
        }

        public var errorDescription: String? {
            switch self {
            case .unhandledRequest(let context):
                return "No mock response registered for \(context.method.rawValue) \(context.path)"
            }
        }
    }

    enum Outcome: Sendable {
        case success(data: Data, response: HTTPURLResponse)
        case failure(Swift.Error)
    }

    struct Handler: Sendable {
        let matches: @Sendable (RequestContext) -> Bool
        let responder: @Sendable (RequestContext) async throws -> Outcome
    }

    private var handlers: [Handler] = []
    private var recordedInteractions: [RequestContext] = []

    public init() {}

    // MARK: - Registration

    @discardableResult
    func register(
        method: HTTPMethod = .get,
        path: String,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        data: Data
    ) -> Self {
        let response = Self.makeResponse(for: path, statusCode: statusCode, headers: headers)
        return register(matcher: Self.matcher(method: method, path: path)) { _ in
            .success(data: data, response: response)
        }
    }

    @discardableResult
    func register<Value: Encodable & Sendable>(
        method: HTTPMethod = .get,
        path: String,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body value: Value,
        encoder: JSONEncoder = .clerkEncoder
    ) throws -> Self {
        let data = try encoder.encode(value)
        return register(method: method, path: path, statusCode: statusCode, headers: headers, data: data)
    }

    @discardableResult
    func registerError(
        _ error: Swift.Error,
        method: HTTPMethod = .get,
        path: String
    ) -> Self {
        register(matcher: Self.matcher(method: method, path: path)) { _ in
            .failure(error)
        }
    }

    @discardableResult
    func register(
        matcher: @escaping @Sendable (RequestContext) -> Bool,
        responder: @escaping @Sendable (RequestContext) -> Outcome
    ) -> Self {
        handlers.append(Handler(matches: matcher) { context in
            responder(context)
        })
        return self
    }

    func clear() {
        handlers.removeAll()
        recordedInteractions.removeAll()
    }

    func recordedRequests() -> [RequestContext] {
        recordedInteractions
    }

    func lastRequest() -> RequestContext? {
        recordedInteractions.last
    }

    // MARK: - Helpers

    private func context<Response>(
        from request: Request<Response>,
        uploadBody: Data?
    ) throws -> RequestContext {
        let body = try bodyData(for: request, uploadBody: uploadBody)
        return RequestContext(
            method: request.method,
            path: request.path,
            headers: request.headers,
            queryItems: request.queryItems,
            body: body
        )
    }

    private func bodyData<Response>(
        for request: Request<Response>,
        uploadBody: Data?
    ) throws -> Data? {
        if let uploadBody {
            return uploadBody
        }

        guard let body = request.body else { return nil }

        switch body.storage {
        case .data(let data):
            return data
        case .encodable(let encodable):
            let encoder = request.encoder ?? JSONEncoder.clerkEncoder
            return try encoder.encode(encodable)
        }
    }

    private func outcome<Response>(
        from request: Request<Response>,
        context: RequestContext
    ) async throws -> Outcome {
        guard let handler = handlers.first(where: { $0.matches(context) }) else {
            return .failure(Error.unhandledRequest(context))
        }

        return try await handler.responder(context)
    }

    private func decode<Response>(
        _ responseType: Response.Type,
        from data: Data,
        using request: Request<Response>
    ) throws -> Response {
        if Response.self == NoContent.self {
            return NoContent() as! Response
        }

        let decoder = request.decoder ?? JSONDecoder.clerkDecoder
        return try decoder.decode(Response.self, from: data)
    }

    private static func matcher(method: HTTPMethod, path: String) -> @Sendable (RequestContext) -> Bool {
        let targetMethod = method
        let normalized = normalize(path)
        return { context in
            context.method == targetMethod && context.normalizedPath == normalized
        }
    }

    private static func normalize(_ path: String) -> String {
        if path.contains("://") {
            return path
        }
        if path.hasPrefix("/") {
            return path
        }
        return "/\(path)"
    }

    private static func makeResponse(
        for path: String,
        statusCode: Int,
        headers: [String: String]
    ) -> HTTPURLResponse {
        let url: URL
        if path.contains("://"), let absolute = URL(string: path) {
            url = absolute
        } else {
            let normalized = normalize(path)
            url = URL(string: "https://clerk.mock\(normalized)")!
        }
        return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
    }
}

extension MockAPIClient: APIClientProtocol {

    @discardableResult
    func send<Response>(_ request: Request<Response>) async throws -> NetworkResponse<Response> {
        let context = try context(from: request, uploadBody: nil)
        recordedInteractions.append(context)

        let outcome = try await outcome(from: request, context: context)

        switch outcome {
        case .success(let data, let response):
            let value = try decode(Response.self, from: data, using: request)
            return NetworkResponse(value: value, response: response, data: data)
        case .failure(let error):
            throw error
        }
    }

    @discardableResult
    func upload<Response>(_ request: Request<Response>, from data: Data) async throws -> NetworkResponse<Response> {
        let context = try context(from: request, uploadBody: data)
        recordedInteractions.append(context)

        let outcome = try await outcome(from: request, context: context)

        switch outcome {
        case .success(let responseData, let response):
            let value = try decode(Response.self, from: responseData, using: request)
            return NetworkResponse(value: value, response: response, data: responseData)
        case .failure(let error):
            throw error
        }
    }
}
