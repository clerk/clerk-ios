@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct ClerkAPIClientTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func requestHeaders() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.allHTTPHeaderFields?["clerk-api-version"] == Clerk.apiVersion)
      #expect(request.allHTTPHeaderFields?["x-ios-sdk-version"] == Clerk.sdkVersion)
      #expect(request.allHTTPHeaderFields?["x-mobile"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func isNativeQueryParameter() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("_is_native=true") == true, "Expected _is_native=true query parameter to be present")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func getRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func postRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["key"] == "value")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post,
      body: ["key": "value"]
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func postRequestWithExplicitJSONContentType() async throws {
    struct Payload: Encodable, Sendable {
      let unsafeMetadata: JSON
    }

    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/json")
      #expect(request.jsonBody?["unsafe_metadata"]?["token"]?.stringValue == "some-value")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post,
      headers: ["Content-Type": "application/json"],
      body: Payload(unsafeMetadata: ["token": "some-value"])
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func patchRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["key"] == "value")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .patch,
      body: ["key": "value"]
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func deleteRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .delete
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func queryParameters() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("param1=value1") == true)
      #expect(queryString.contains("param2=value2") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get,
      query: [("param1", "value1"), ("param2", "value2")]
    )

    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    #expect(requestHandled.value)
  }

  @Test
  func multipartUpload() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!
    let boundary = UUID().uuidString
    var data = Data()
    try data.append(#require("\r\n--\(boundary)\r\n".data(using: .utf8)))
    try data.append(#require("Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n".data(using: .utf8)))
    try data.append(#require("Content-Type: text/plain\r\n\r\n".data(using: .utf8)))
    try data.append(#require("test content".data(using: .utf8)))
    try data.append(#require("\r\n--\(boundary)--\r\n".data(using: .utf8)))

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
    )

    _ = try await Clerk.shared.dependencies.apiClient.upload(for: request, from: data)
    #expect(requestHandled.value)
  }

  @Test
  func errorHandling() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 400,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [.mock],
            clerkTraceId: nil
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get
    )

    do {
      _ = try await Clerk.shared.dependencies.apiClient.send(request)
      #expect(Bool(false), "Expected error to be thrown")
    } catch {
      #expect(requestHandled.value)
    }
  }

  @Test
  func retryPreservesFirstPreparedSharedIdentityContext() async throws {
    let prepareCount = LockIsolated(0)
    let observedContexts = LockIsolated<[(UInt64?, String?, String?, Bool)]>([])
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/retry-context")!
    let mock = try Mock(
      url: testURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [.get: JSONEncoder().encode(["success": true])]
    )
    mock.register()
    let pipeline = NetworkingPipeline(
      requestMiddleware: [ChangingSharedIdentityContextMiddleware(count: prepareCount)],
      responseMiddleware: [RecordingRetryContextMiddleware(contexts: observedContexts)],
      retryMiddleware: [RetryFirstContextFailureMiddleware()]
    )
    let apiClient = APIClient(
      baseURL: mockBaseUrl,
      runtimeScope: Clerk.shared.runtimeScope
    ) { configuration in
      configuration.pipeline = pipeline
    }

    _ = try await apiClient.send(Request<EmptyResponse>(path: "/v1/retry-context"))

    #expect(prepareCount.value == 2)
    #expect(observedContexts.value.count == 2)
    #expect(observedContexts.value.allSatisfy {
      $0.0 == 1 && $0.1 == "token-1" && $0.2 == "client-1" && $0.3
    })
  }

  @Test
  func retryRestoresFrozenClerkContextBeforeCustomSigningMiddleware() async throws {
    let prepareCount = LockIsolated(0)
    let observedContexts = LockIsolated<[(UInt64?, String?, String?, Bool)]>([])
    let signedAuthorizations = LockIsolated<[String?]>([])
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/retry-signature")!
    let mock = try Mock(
      url: testURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [.get: JSONEncoder().encode(["success": true])]
    )
    mock.register()
    let pipeline = NetworkingPipeline(
      requestMiddleware: [ChangingSharedIdentityContextMiddleware(count: prepareCount)],
      responseMiddleware: [RecordingRetryContextMiddleware(contexts: observedContexts)],
      retryMiddleware: [RetryFirstContextFailureMiddleware()]
    ).appendingRequestMiddleware([
      SigningFrozenContextMiddleware(authorizations: signedAuthorizations),
    ])
    let apiClient = APIClient(
      baseURL: mockBaseUrl,
      runtimeScope: Clerk.shared.runtimeScope
    ) { configuration in
      configuration.pipeline = pipeline
    }

    _ = try await apiClient.send(Request<EmptyResponse>(path: "/v1/retry-signature"))

    #expect(prepareCount.value == 2)
    #expect(signedAuthorizations.value == ["token-1", "token-1"])
    #expect(observedContexts.value.allSatisfy { $0.1 == "token-1" })
  }
}

private struct ChangingSharedIdentityContextMiddleware: ClerkRequestMiddleware {
  let count: LockIsolated<Int>

  func prepare(_ request: inout URLRequest) async throws {
    let attempt = count.withValue {
      $0 += 1
      return $0
    }
    request.setClerkSharedSessionBaseGeneration(UInt64(attempt))
    request.setClerkCanonicalClientRequest(attempt == 1)
    request.setValue("token-\(attempt)", forHTTPHeaderField: "Authorization")
    request.setValue("client-\(attempt)", forHTTPHeaderField: "x-clerk-client-id")
  }
}

private struct SigningFrozenContextMiddleware: ClerkRequestMiddleware {
  let authorizations: LockIsolated<[String?]>

  func prepare(_ request: inout URLRequest) async throws {
    let authorization = request.value(forHTTPHeaderField: "Authorization")
    authorizations.withValue { $0.append(authorization) }
    request.setValue("signed:\(authorization ?? "none")", forHTTPHeaderField: "X-Test-Signature")
  }
}

private struct RecordingRetryContextMiddleware: ClerkResponseMiddleware {
  enum Failure: Error {
    case firstAttempt
  }

  let contexts: LockIsolated<[(UInt64?, String?, String?, Bool)]>

  func validate(_: HTTPURLResponse, data _: Data, for request: URLRequest) async throws {
    let count = contexts.withValue {
      $0.append((
        request.clerkSharedSessionBaseGeneration,
        request.value(forHTTPHeaderField: "Authorization"),
        request.value(forHTTPHeaderField: "x-clerk-client-id"),
        request.clerkIsCanonicalClientRequest
      ))
      return $0.count
    }
    if count == 1 {
      throw Failure.firstAttempt
    }
  }
}

private struct RetryFirstContextFailureMiddleware: NetworkRetryMiddleware {
  func shouldRetry(
    request _: URLRequest,
    response _: HTTPURLResponse?,
    error: any Error,
    attempts: Int
  ) async throws -> Bool {
    error is RecordingRetryContextMiddleware.Failure && attempts == 1
  }
}
