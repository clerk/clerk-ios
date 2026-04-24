@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct ClerkAPIClientTests {
  private func makeAPIClient(
    baseURL: URL,
    clientId: String? = nil,
    includeNativeQueryMiddleware: Bool = true
  ) -> APIClient {
    let keychain = InMemoryKeychain()
    let requestMiddleware: [any ClerkRequestMiddleware] = {
      var middleware: [any ClerkRequestMiddleware] = [
        ClerkHeaderRequestMiddleware(
          keychainProvider: { keychain },
          clientIdProvider: { clientId }
        ),
      ]

      if includeNativeQueryMiddleware {
        middleware.append(ClerkQueryItemsRequestMiddleware())
      }

      middleware.append(ClerkURLEncodedFormEncoderMiddleware())
      return middleware
    }()

    return APIClient(baseURL: baseURL) { @Sendable configuration in
      configuration.pipeline = NetworkingPipeline(
        requestMiddleware: requestMiddleware,
        responseMiddleware: [
          ClerkErrorThrowingResponseMiddleware(),
        ]
      )
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.protocolClasses = [IsolatedMockURLProtocol.self]
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": Clerk.apiVersion,
        "x-ios-sdk-version": Clerk.sdkVersion,
        "x-mobile": "1",
      ]
    }
  }

  @Test
  func requestHeaders() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .post,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.allHTTPHeaderFields?["clerk-api-version"] == Clerk.apiVersion)
      #expect(request.allHTTPHeaderFields?["x-ios-sdk-version"] == Clerk.sdkVersion)
      #expect(request.allHTTPHeaderFields?["x-mobile"] == "1")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post
    )

    _ = try await makeAPIClient(baseURL: baseURL, includeNativeQueryMiddleware: false).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func isNativeQueryParameter() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .get,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "GET")
      let queryString = request.url?.query ?? ""
      #expect(queryString.contains("_is_native=true") == true, "Expected _is_native=true query parameter to be present")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get
    )

    _ = try await makeAPIClient(baseURL: baseURL).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func getRequest() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .get,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get
    )

    _ = try await makeAPIClient(baseURL: baseURL).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func postRequest() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .post,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["key"] == "value")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post,
      body: ["key": "value"]
    )

    _ = try await makeAPIClient(baseURL: baseURL).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func postRequestWithExplicitJSONContentType() async throws {
    struct Payload: Encodable, Sendable {
      let unsafeMetadata: JSON
    }

    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .post,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/json")
      #expect(request.jsonBody?["unsafe_metadata"]?["token"]?.stringValue == "some-value")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post,
      headers: ["Content-Type": "application/json"],
      body: Payload(unsafeMetadata: ["token": "some-value"])
    )

    _ = try await makeAPIClient(baseURL: baseURL).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func patchRequest() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .patch,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["key"] == "value")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .patch,
      body: ["key": "value"]
    )

    _ = try await makeAPIClient(baseURL: baseURL).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func deleteRequest() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .delete,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .delete
    )

    _ = try await makeAPIClient(baseURL: baseURL).send(request)
    #expect(requestHandled.value)
  }

  @Test
  func queryParameters() throws {
    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get,
      query: [("param1", "value1"), ("param2", "value2")]
    )

    let urlRequest = try request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder)
    let queryString = urlRequest.url?.query ?? ""
    #expect(queryString.contains("param1=value1") == true)
    #expect(queryString.contains("param2=value2") == true)
  }

  @Test
  func queryParametersOmitNilValues() throws {
    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get,
      query: [("param1", "value1"), ("_clerk_session_id", nil)]
    )

    let urlRequest = try request.makeURLRequest(baseURL: mockBaseUrl, encoder: .clerkEncoder)
    let queryString = urlRequest.url?.query ?? ""
    #expect(queryString.contains("param1=value1") == true)
    #expect(queryString.contains("_clerk_session_id") == false)
  }

  @Test
  func multipartUpload() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")
    let boundary = UUID().uuidString
    var data = Data()
    try data.append(#require("\r\n--\(boundary)\r\n".data(using: .utf8)))
    try data.append(#require("Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n".data(using: .utf8)))
    try data.append(#require("Content-Type: text/plain\r\n\r\n".data(using: .utf8)))
    try data.append(#require("test content".data(using: .utf8)))
    try data.append(#require("\r\n--\(boundary)--\r\n".data(using: .utf8)))

    try registerIsolatedStub(
      url: testURL,
      method: .post,
      data: JSONEncoder().encode(["success": true])
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.allHTTPHeaderFields?["Content-Type"]?.contains("multipart/form-data") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
    )

    _ = try await makeAPIClient(baseURL: baseURL).upload(for: request, from: data)
    #expect(requestHandled.value)
  }

  @Test
  func errorHandling() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let testURL = baseURL.appendingPathComponent("v1/test")

    try registerIsolatedStub(
      url: testURL,
      method: .get,
      statusCode: 400,
      data: JSONEncoder.clerkEncoder.encode(
        ClerkErrorResponse(
          errors: [.mock],
          clerkTraceId: nil
        )
      )
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: testURL) }

    let request = Request<EmptyResponse>(
      path: "/v1/test",
      method: .get
    )

    do {
      _ = try await makeAPIClient(baseURL: baseURL).send(request)
      #expect(Bool(false), "Expected error to be thrown")
    } catch {
      #expect(requestHandled.value)
    }
  }
}
