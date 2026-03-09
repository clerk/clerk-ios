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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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

    mock.onRequestHandler = OnRequestHandler { request in
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
  func requestSequenceNumberIncreases() async throws {
    let requestSequences = LockIsolated<[Int]>([])
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder().encode(["success": true]),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      if let sequence = request.clerkRequestSequence {
        requestSequences.withValue { $0.append(sequence) }
      }
    }
    mock.register()

    let request = Request<EmptyResponse>(path: "/v1/test", method: .get)

    // Make multiple requests
    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    _ = try await Clerk.shared.dependencies.apiClient.send(request)
    _ = try await Clerk.shared.dependencies.apiClient.send(request)

    let sequences = requestSequences.value
    #expect(sequences.count == 3)
    #expect(sequences[0] < sequences[1])
    #expect(sequences[1] < sequences[2])
  }

  @Test
  func serverErrorReturnsError() async throws {
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    let mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 500,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [
              ClerkAPIError(code: "internal_error", message: "Internal server error", longMessage: nil)
            ],
            clerkTraceId: "trace123"
          )
        ),
      ]
    )
    mock.register()

    let request = Request<EmptyResponse>(path: "/v1/test", method: .get)

    do {
      _ = try await Clerk.shared.dependencies.apiClient.send(request)
      #expect(Bool(false), "Expected error to be thrown")
    } catch let error as ClerkAPIError {
      #expect(error.code == "internal_error")
      #expect(error.clerkTraceId == "trace123")
    }
  }

  @Test
  func responseDecodingToExpectedType() async throws {
    struct TestResponse: Codable, Sendable {
      let id: String
      let name: String
    }

    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!
    let expectedResponse = TestResponse(id: "test123", name: "Test Name")

    let mock = try Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(expectedResponse),
      ]
    )
    mock.register()

    let request = Request<TestResponse>(path: "/v1/test", method: .get)
    let response = try await Clerk.shared.dependencies.apiClient.send(request)

    #expect(response.value.id == "test123")
    #expect(response.value.name == "Test Name")
  }
}