//
//  RequestCaptureURLProtocol.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation

/// A custom URLProtocol that captures all URLRequests for testing purposes.
final class RequestCaptureURLProtocol: URLProtocol {

  /// Thread-safe storage for captured requests
  /// Marked as nonisolated(unsafe) since it's protected by locks and only used in tests
  nonisolated(unsafe) private static var capturedRequests: [URLRequest] = []
  private static let lock = NSLock()

  /// Reset captured requests (call before each test)
  /// Clears all captured requests to ensure test isolation
  /// Note: Since tests are serialized within suites, this should work for most cases
  static func reset() {
    lock.lock()
    defer { lock.unlock() }
    capturedRequests.removeAll()
  }

  /// Get all captured requests
  static func getCapturedRequests() -> [URLRequest] {
    lock.lock()
    defer { lock.unlock() }
    return capturedRequests
  }

  /// Get the last captured request since the last reset for this test
  static func getLastRequest() -> URLRequest? {
    let requests = getCapturedRequests()
    return requests.last
  }

  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    // Capture a copy of the request (URLRequest can be mutated)
    var capturedRequest = request

    // Capture body from either httpBody or httpBodyStream
    if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
      stream.open()
      defer { stream.close() }
      let bufferSize = 1024
      var buffer = [UInt8](repeating: 0, count: bufferSize)
      var data = Data()
      while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 {
          break
        }
        if bytesRead == 0 {
          break
        }
        data.append(buffer, count: bytesRead)
      }
      // Reset stream position and set httpBody
      capturedRequest.httpBody = data
    }

    Self.lock.lock()
    Self.capturedRequests.append(capturedRequest)
    Self.lock.unlock()

    // Create a mock response
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    // Return empty JSON response
    let emptyJSON = "{}".data(using: .utf8) ?? Data()

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: emptyJSON)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {
    // No-op
  }
}
