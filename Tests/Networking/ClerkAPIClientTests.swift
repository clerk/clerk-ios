import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ClerkAPIClientTests {

  init() {
    configureClerkForTesting()
  }

  @Test
  func testRequestHeaders() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder().encode(["success": true])
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/x-www-form-urlencoded")
      #expect(request.allHTTPHeaderFields?["clerk-api-version"] == "2025-04-10")
      #expect(request.allHTTPHeaderFields?["x-ios-sdk-version"] == Clerk.version)
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
  func testIsNativeQueryParameter() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder().encode(["success": true])
      ])

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
  func testGetRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder().encode(["success": true])
      ])

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
  func testPostRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder().encode(["success": true])
      ])

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
  func testPatchRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder().encode(["success": true])
      ])

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
  func testDeleteRequest() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder().encode(["success": true])
      ])

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
  func testQueryParameters() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder().encode(["success": true])
      ])

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
  func testMultipartUpload() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!
    let boundary = UUID().uuidString
    var data = Data()
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
    data.append("test content".data(using: .utf8)!)
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder().encode(["success": true])
      ])

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
  func testErrorHandling() async throws {
    let requestHandled = LockIsolated(false)
    let testURL = URL(string: mockBaseUrl.absoluteString + "/v1/test")!

    var mock = Mock(
      url: testURL, ignoreQuery: true, contentType: .json, statusCode: 400,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(
          ClerkErrorResponse(
            errors: [.mock],
            clerkTraceId: nil
          ))
      ])

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
}
