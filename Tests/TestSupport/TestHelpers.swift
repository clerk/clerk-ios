@testable import ClerkKit
import Foundation
import Mocker

let mockBaseUrl = URL(string: "https://mock.clerk.accounts.dev")!

/// Test publishable key that decodes to mock.clerk.accounts.dev
let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

extension Clerk {
  @MainActor
  func applyResponseClient(
    _ incoming: Client?,
    responseSequence: Int? = nil,
    serverDate: Date? = nil,
    clientResponseGeneration: ClientResponseGeneration? = nil,
    completedAuthFlow: TransferFlowResult? = nil
  ) {
    identityController.applyLegacyResponseClient(
      incoming,
      responseSequence: responseSequence,
      serverDate: serverDate,
      clientResponseGeneration: clientResponseGeneration,
      completedAuthFlow: completedAuthFlow,
      completedAuthFlowOwnerId: authFlowRegistrationId
    )
  }
}

/// Configures isolated Clerk state with injectable service implementations.
@MainActor
func configureClerkForTesting() {
  Clerk.engineClient = nil
  Clerk.makeEngineClient = nil

  // Configure Clerk with test publishable key
  Clerk.configure(publishableKey: testPublishableKey)

  setupMockDependencies()

  // Unit tests should not inherit startup refreshes or session polling from configure().
  Clerk.shared.cleanupManagers()
}

@MainActor
func setupMockDependencies() {
  Clerk.shared.dependencies = MockDependencyContainer(
    telemetryCollector: Clerk.shared.dependencies.telemetryCollector,
    userService: UserService(),
    signInService: SignInService(),
    sessionService: SessionService(),
    passkeyService: PasskeyService(),
    organizationService: OrganizationService()
  )
}

/// Creates a mock API client configured to use MockingURLProtocol for testing.
extension URLRequest {
  /// Returns request body data from `httpBody` or `httpBodyStream`.
  var requestBodyData: Data? {
    if let body = httpBody {
      return body
    }

    guard let bodyStream = httpBodyStream else {
      return nil
    }

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

    return data.isEmpty ? nil : data
  }

  /// Extracts the URL-encoded form data from the request body as a dictionary.
  ///
  /// Handles both `httpBody` and `httpBodyStream` properties, as URLSession may use either.
  /// Returns `nil` if the body cannot be read or parsed.
  var urlEncodedFormBody: [String: String]? {
    guard let requestBodyData,
          let bodyString = String(data: requestBodyData, encoding: .utf8)
    else {
      return nil
    }

    // Parse URL-encoded form data: "key1=value1&key2=value2"
    var bodyDict: [String: String] = [:]
    let pairs = bodyString.split(separator: "&")
    for pair in pairs {
      let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      if parts.count == 2 {
        let key = String(parts[0])
        let value = String(parts[1])
        // URL-decode the value
        bodyDict[key] = value.removingPercentEncoding ?? value
      }
    }

    return bodyDict.isEmpty ? nil : bodyDict
  }

  /// Extracts URL-encoded form data preserving repeated keys as arrays.
  ///
  /// Use this instead of `urlEncodedFormBody` when the request may contain
  /// repeated keys (e.g. `additional_scope=write&additional_scope=view`).
  var urlEncodedFormBodyMultiValue: [String: [String]]? {
    guard let requestBodyData,
          let bodyString = String(data: requestBodyData, encoding: .utf8)
    else {
      return nil
    }

    var bodyDict: [String: [String]] = [:]
    let pairs = bodyString.split(separator: "&")
    for pair in pairs {
      let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      if parts.count == 2 {
        let key = String(parts[0])
        let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        bodyDict[key, default: []].append(value)
      }
    }

    return bodyDict.isEmpty ? nil : bodyDict
  }

  /// Decodes request body as `JSON`.
  var jsonBody: JSON? {
    guard let requestBodyData else { return nil }
    return try? JSONDecoder.clerkDecoder.decode(JSON.self, from: requestBodyData)
  }
}
