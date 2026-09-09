@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct AppleHTTPCapabilityTests {
  private func capabilities() throws -> AppleCapabilities {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HTTPFixtureProtocol.self]
    return try AppleCapabilities(publishableKey: "fixture", frontendAPI: #require(URL(string: "https://example.com")), storage: HTTPUnusedStorage(), sessionConfiguration: configuration)
  }

  private func arguments(url: String = "https://example.com/v1/test?value=a%26b", method: String = "POST", headers: [String: JSONValue] = [:], body: JSONValue = .undefined) -> JSONValue {
    var value: [String: JSONValue] = ["url": .string(url), "method": .string(method), "headers": .object(headers)]
    if !body.isUndefined { value["body"] = body }
    return .object(value)
  }

  @Test func preservesMethodsQueriesBodiesHeadersAndErrorResponses() async throws {
    let host = try capabilities()
    for method in ["GET", "POST", "PATCH", "DELETE"] {
      HTTPFixtureProtocol.configure { request, client, fixture in
        #expect(request.httpMethod == method)
        #expect(request.url?.query == "value=a%26b")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "fixture-token")
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(request.httpShouldHandleCookies == false)
        #expect(try HTTPFixtureProtocol.body(request) == (method == "GET" ? Data() : Data("key=a%26b".utf8)))
        let requestURL = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: requestURL, statusCode: 422, httpVersion: nil, headerFields: ["X-Clerk-Trace-Id": "fixture-trace"]))
        client.urlProtocol(fixture, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(fixture, didLoad: Data("{\"errors\":[]}".utf8))
        client.urlProtocolDidFinishLoading(fixture)
      }
      let result = try await host.perform("http", arguments: arguments(method: method, headers: ["Authorization": .string("fixture-token")], body: method == "GET" ? .undefined : .string("key=a%26b"))).object()
      #expect(result["status"] == .number(422))
      #expect(result["body"] == .string("{\"errors\":[]}"))
      let headers = try #require(result["headers"]).object()
      #expect(headers["x-clerk-trace-id"] == .string("fixture-trace"))
    }
  }

  @Test func rejectsUntrustedOriginsAndInjectedHeadersBeforeHTTP() async throws {
    let host = try capabilities()
    HTTPFixtureProtocol.configure { _, client, fixture in
      Issue.record("Invalid input reached HTTP")
      client.urlProtocol(fixture, didFailWithError: URLError(.badURL))
    }
    for url in ["http://example.com/v1/test", "https://other.example/v1/test", "https://example.com:444/v1/test", "https://user:password@example.com/v1/test"] {
      await #expect(throws: CoreError.self) { try await host.perform("http", arguments: arguments(url: url)) }
    }
    let invalidHeaders: [[String: JSONValue]] = [["Cookie": .string("secret")], ["coOKie": .string("secret")], ["X-Test\r\nInjected": .string("value")], ["X-Test": .string("value\r\nInjected: true")]]
    for headers in invalidHeaders {
      await #expect(throws: CoreError.self) { try await host.perform("http", arguments: arguments(headers: headers)) }
    }
    await #expect(throws: CoreError.self) {
      try await host.perform("http", arguments: arguments(body: .object(["multipart": .array([
        .object(["name": .string("file"), "filename": .string("file.bin"), "contentType": .string("text/plain\r\nInjected: true"), "base64": .string("AA==")]),
      ])])))
    }
  }

  @Test func encodesMultipartTextAndBinaryWithoutHeaderInjection() async throws {
    let host = try capabilities()
    HTTPFixtureProtocol.configure { request, client, fixture in
      let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
      #expect(contentType.hasPrefix("multipart/form-data; boundary="))
      let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
      let data = try HTTPFixtureProtocol.body(request)
      var expected = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\ntext\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"image\\\".bin\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
      expected.append(contentsOf: [0, 255, 10, 13])
      expected.append(Data("\r\n--\(boundary)--\r\n".utf8))
      #expect(data == expected)
      let requestURL = try #require(request.url)
      let response = try #require(HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil))
      client.urlProtocol(fixture, didReceive: response, cacheStoragePolicy: .notAllowed)
      client.urlProtocolDidFinishLoading(fixture)
    }
    _ = try await host.perform("http", arguments: arguments(body: .object(["multipart": .array([
      .object(["name": .string("note"), "value": .string("text")]),
      .object(["name": .string("file"), "filename": .string("image\"\r\n.bin"), "contentType": .string("application/octet-stream"), "base64": .string("AP8KDQ==")]),
    ])])))
  }

  @Test func rejectsInvalidUTF8AndSurfacesNetworkFailure() async throws {
    let host = try capabilities()
    HTTPFixtureProtocol.configure { request, client, fixture in
      let requestURL = try #require(request.url)
      let response = try #require(HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: nil, headerFields: nil))
      client.urlProtocol(fixture, didReceive: response, cacheStoragePolicy: .notAllowed)
      client.urlProtocol(fixture, didLoad: Data([255]))
      client.urlProtocolDidFinishLoading(fixture)
    }
    await #expect(throws: CoreError.self) { try await host.perform("http", arguments: arguments()) }
    HTTPFixtureProtocol.configure { _, client, fixture in client.urlProtocol(fixture, didFailWithError: URLError(.notConnectedToInternet)) }
    await #expect(throws: URLError.self) { try await host.perform("http", arguments: arguments()) }
  }

  @Test(.timeLimit(.minutes(1))) func cancellationStopsTheURLSessionRequest() async throws {
    let host = try capabilities()
    let (started, continuation) = AsyncStream<Void>.makeStream()
    HTTPFixtureProtocol.configure { _, _, _ in continuation.yield() }
    let task = Task { try await host.perform("http", arguments: arguments()) }
    for await _ in started {
      break
    }
    task.cancel()
    await #expect(throws: (any Error).self) { try await task.value }
    continuation.finish()
  }

  @Test func redirectsPreserveTheSameOriginCredentialRestriction() async throws {
    let origin = try #require(URL(string: "https://example.com"))
    let delegate = SameOriginRedirects(origin: origin)
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let task = session.dataTask(with: origin)
    let response = try #require(HTTPURLResponse(url: origin, statusCode: 302, httpVersion: nil, headerFields: nil))
    for target in ["https://example.com/v1/next", "https://other.example/v1/next", "http://example.com/v1/next", "https://example.com:444/v1/next", "https://user:password@example.com/v1/next"] {
      let request = try URLRequest(url: #require(URL(string: target)))
      let result = await withCheckedContinuation { continuation in
        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request) { continuation.resume(returning: $0) }
      }
      #expect((result != nil) == (target == "https://example.com/v1/next"))
    }
  }
}

private final class HTTPFixtureProtocol: URLProtocol, @unchecked Sendable {
  typealias Handler = @Sendable (URLRequest, any URLProtocolClient, HTTPFixtureProtocol) throws -> Void
  private static let lock = NSLock()
  private nonisolated(unsafe) static var handler: Handler?
  static func configure(_ value: @escaping Handler) {
    lock.withLock { handler = value }
  }

  override class func canInit(with _: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let client, let handler = Self.lock.withLock({ Self.handler }) else { return }
    do { try handler(request, client, self) }
    catch { client.urlProtocol(self, didFailWithError: error) }
  }

  override func stopLoading() {}
  static func body(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
      if count == 0 { return result }
      result.append(contentsOf: buffer.prefix(count))
    }
  }
}

private actor HTTPUnusedStorage: CredentialStorage {
  func read() throws -> String? {
    throw CoreError(code: "unexpected_storage")
  }

  func write(_: String) throws {
    throw CoreError(code: "unexpected_storage")
  }

  func remove() throws {
    throw CoreError(code: "unexpected_storage")
  }
}
