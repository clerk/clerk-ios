import FactoryKit
import Foundation
import Mocker

@testable import ClerkKit

let mockBaseUrl = URL(string: "https://mock.clerk.accounts.dev")!

/// Test publishable key that decodes to mock.clerk.accounts.dev
let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

/// Configures Clerk for testing and registers the API client with MockingURLProtocol.
/// This ensures that HTTP requests are intercepted by Mocker instead of reaching the real API.
@MainActor
func configureClerkForTesting() {
  Clerk.configure(publishableKey: testPublishableKey)
  registerMockingAPIClient()
}

/// Re-registers the API client with MockingURLProtocol after Clerk.configure() overrides it.
/// This ensures that HTTP requests are intercepted by Mocker instead of reaching the real API.
private func registerMockingAPIClient() {
  Container.shared.apiClient.register {
    APIClient(baseURL: mockBaseUrl) { configuration in
      configuration.pipeline = Container.shared.networkingPipeline()
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": "2025-04-10",
        "x-ios-sdk-version": Clerk.version,
        "x-mobile": "1"
      ]
    }
  }
}

extension URLRequest {
  /// Extracts the URL-encoded form data from the request body as a dictionary.
  ///
  /// Handles both `httpBody` and `httpBodyStream` properties, as URLSession may use either.
  /// Returns `nil` if the body cannot be read or parsed.
  var urlEncodedFormBody: [String: String]? {
    // Try to get body data from either httpBody or httpBodyStream
    let bodyData: Data?
    if let body = httpBody {
      bodyData = body
    } else if let bodyStream = httpBodyStream {
      var data = Data()
      bodyStream.open()
      defer { bodyStream.close() }
      let bufferSize = 4096
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
      defer { buffer.deallocate() }
      while bodyStream.hasBytesAvailable {
        let read = bodyStream.read(buffer, maxLength: bufferSize)
        if read > 0 {
          data.append(buffer, count: read)
        } else {
          break
        }
      }
      bodyData = data.isEmpty ? nil : data
    } else {
      bodyData = nil
    }

    guard let bodyData = bodyData,
      let bodyString = String(data: bodyData, encoding: .utf8)
    else {
      return nil
    }

    // Parse URL-encoded form data: "key1=value1&key2=value2"
    var bodyDict: [String: String] = [:]
    let pairs = bodyString.split(separator: "&")
    for pair in pairs {
      let parts = pair.split(separator: "=", maxSplits: 1)
      if parts.count == 2 {
        let key = String(parts[0])
        let value = String(parts[1])
        // URL-decode the value
        bodyDict[key] = value.removingPercentEncoding ?? value
      }
    }

    return bodyDict.isEmpty ? nil : bodyDict
  }
}
