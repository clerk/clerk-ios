@testable import ClerkKit
import Foundation
import Mocker
import Testing

let mockBaseUrl = URL(string: "https://mock.clerk.accounts.dev")!

/// Test publishable key that decodes to mock.clerk.accounts.dev
let testPublishableKey = Clerk.mockPublishableKey

typealias TestURLProtocolHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

private final class TestURLProtocolRegistry: @unchecked Sendable {
  static let shared = TestURLProtocolRegistry()

  private let lock = NSLock()
  private var handlers: [String: TestURLProtocolHandler] = [:]

  func register(host: String, handler: @escaping TestURLProtocolHandler) {
    lock.lock()
    defer { lock.unlock() }
    handlers[host] = handler
  }

  func handler(for host: String) -> TestURLProtocolHandler? {
    lock.lock()
    defer { lock.unlock() }
    return handlers[host]
  }

  func remove(host: String) {
    lock.lock()
    defer { lock.unlock() }
    handlers.removeValue(forKey: host)
  }
}

final class IsolatedMockURLProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool {
    guard let host = request.url?.host else { return false }
    return TestURLProtocolRegistry.shared.handler(for: host) != nil
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard
      let url = request.url,
      let host = url.host,
      let handler = TestURLProtocolRegistry.shared.handler(for: host)
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

@MainActor
final class ClerkTestFixture {
  init() {}

  func register(_ mock: Mock) {
    mock.register()
  }

  @discardableResult
  func makeMockDependencies(
    apiClient: APIClient? = nil,
    keychain: (any KeychainStorage)? = nil,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil,
    clientService: (any ClientServiceProtocol)? = nil,
    userService: (any UserServiceProtocol)? = nil,
    signInService: (any SignInServiceProtocol)? = nil,
    signUpService: (any SignUpServiceProtocol)? = nil,
    sessionService: (any SessionServiceProtocol)? = nil,
    passkeyService: (any PasskeyServiceProtocol)? = nil,
    organizationService: (any OrganizationServiceProtocol)? = nil,
    environmentService: (any EnvironmentServiceProtocol)? = nil,
    emailAddressService: (any EmailAddressServiceProtocol)? = nil,
    phoneNumberService: (any PhoneNumberServiceProtocol)? = nil,
    externalAccountService: (any ExternalAccountServiceProtocol)? = nil,
    options: Clerk.Options = .init()
  ) throws -> MockDependencyContainer {
    let container = MockDependencyContainer(
      apiClient: apiClient ?? createMockAPIClient(),
      keychain: keychain,
      telemetryCollector: telemetryCollector,
      clientService: clientService,
      userService: userService,
      signInService: signInService,
      signUpService: signUpService,
      sessionService: sessionService,
      passkeyService: passkeyService,
      organizationService: organizationService,
      environmentService: environmentService,
      emailAddressService: emailAddressService,
      phoneNumberService: phoneNumberService,
      externalAccountService: externalAccountService
    )

    try container.configurationManager.configure(publishableKey: testPublishableKey, options: options)

    return container
  }

  func makeClerk(
    apiClient: APIClient? = nil,
    keychain: (any KeychainStorage)? = nil,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil,
    clientService: (any ClientServiceProtocol)? = nil,
    userService: (any UserServiceProtocol)? = nil,
    signInService: (any SignInServiceProtocol)? = nil,
    signUpService: (any SignUpServiceProtocol)? = nil,
    sessionService: (any SessionServiceProtocol)? = nil,
    passkeyService: (any PasskeyServiceProtocol)? = nil,
    organizationService: (any OrganizationServiceProtocol)? = nil,
    environmentService: (any EnvironmentServiceProtocol)? = nil,
    emailAddressService: (any EmailAddressServiceProtocol)? = nil,
    phoneNumberService: (any PhoneNumberServiceProtocol)? = nil,
    externalAccountService: (any ExternalAccountServiceProtocol)? = nil,
    options: Clerk.Options = .init(),
    client: Client? = nil,
    environment: Clerk.Environment? = nil
  ) throws -> Clerk {
    let clerk = try Clerk(
      dependencies: makeMockDependencies(
        apiClient: apiClient,
        keychain: keychain,
        telemetryCollector: telemetryCollector,
        clientService: clientService,
        userService: userService,
        signInService: signInService,
        signUpService: signUpService,
        sessionService: sessionService,
        passkeyService: passkeyService,
        organizationService: organizationService,
        environmentService: environmentService,
        emailAddressService: emailAddressService,
        phoneNumberService: phoneNumberService,
        externalAccountService: externalAccountService,
        options: options
      )
    )
    clerk.client = client
    clerk.environment = environment
    clerk.sessionsByUserId = [:]
    return clerk
  }
}

@MainActor
func makeBareClerk(
  client: Client? = nil,
  environment: Clerk.Environment? = nil
) -> Clerk {
  try! ClerkTestFixture().makeClerk(client: client, environment: environment)
}

private enum TestWaitError: LocalizedError {
  case timedOut(String)

  var errorDescription: String? {
    switch self {
    case .timedOut(let description):
      description
    }
  }
}

@MainActor
func waitUntil(
  _ description: String,
  timeout: Duration = .seconds(1),
  pollingInterval: Duration = .milliseconds(10),
  condition: () throws -> Bool
) async throws {
  let deadline = ContinuousClock.now + timeout

  while ContinuousClock.now < deadline {
    if try condition() {
      return
    }

    try await Task.sleep(for: pollingInterval)
  }

  if try condition() {
    return
  }

  throw TestWaitError.timedOut("Timed out waiting for \(description)")
}

/// Creates a mock API client configured to use MockingURLProtocol for testing.
@MainActor
func createMockAPIClient() -> APIClient {
  APIClient(baseURL: mockBaseUrl) { @Sendable configuration in
    configuration.pipeline = .clerkDefault
    configuration.decoder = .clerkDecoder
    configuration.encoder = .clerkEncoder
    configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    configuration.sessionConfiguration.httpAdditionalHeaders = [
      "Content-Type": "application/x-www-form-urlencoded",
      "clerk-api-version": Clerk.apiVersion,
      "x-ios-sdk-version": Clerk.sdkVersion,
      "x-mobile": "1",
    ]
  }
}

/// Creates a mock API client for isolated service/request tests without the
/// default `Clerk` middleware stack.
@MainActor
func createIsolatedMockAPIClient(
  baseURL: URL = mockBaseUrl,
  protocolClass: AnyClass = MockingURLProtocol.self
) -> APIClient {
  APIClient(baseURL: baseURL) { @Sendable configuration in
    configuration.pipeline = NetworkingPipeline(
      requestMiddleware: [
        ClerkQueryItemsRequestMiddleware(),
        ClerkURLEncodedFormEncoderMiddleware(),
      ]
    )
    configuration.decoder = .clerkDecoder
    configuration.encoder = .clerkEncoder
    configuration.sessionConfiguration.protocolClasses = [protocolClass]
    configuration.sessionConfiguration.httpAdditionalHeaders = [
      "Content-Type": "application/x-www-form-urlencoded",
      "clerk-api-version": Clerk.apiVersion,
      "x-ios-sdk-version": Clerk.sdkVersion,
      "x-mobile": "1",
    ]
  }
}

func makeIsolatedMockBaseURL(path: String = "") -> URL {
  var components = URLComponents(url: mockBaseUrl, resolvingAgainstBaseURL: false)!
  components.host = "\(UUID().uuidString.lowercased()).mock.clerk.accounts.dev"
  components.path = path
  return components.url!
}

func registerIsolatedStub(
  url: URL,
  method: HTTPMethod,
  statusCode: Int = 200,
  headers: [String: String] = ["Content-Type": "application/json"],
  data: Data,
  onRequest: @escaping @Sendable (URLRequest) throws -> Void = { _ in }
) {
  guard let host = url.host else {
    Issue.record("registerIsolatedStub requires a URL with a host")
    return
  }

  TestURLProtocolRegistry.shared.register(host: host) { request in
    guard request.httpMethod == method.rawValue else {
      throw URLError(.badServerResponse)
    }

    guard
      let requestURL = request.url,
      var requestComponents = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
      var expectedComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      throw URLError(.badURL)
    }

    requestComponents.host = nil
    requestComponents.scheme = nil
    expectedComponents.host = nil
    expectedComponents.scheme = nil

    guard requestComponents.path == expectedComponents.path else {
      throw URLError(.resourceUnavailable)
    }

    try onRequest(request)

    let response = HTTPURLResponse(
      url: requestURL,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: headers
    )!
    return (response, data)
  }
}

func removeIsolatedStub(for url: URL) {
  guard let host = url.host else { return }
  TestURLProtocolRegistry.shared.remove(host: host)
}

extension URLRequest {
  /// Returns request body data from `httpBody` or `httpBodyStream`.
  private var requestBodyData: Data? {
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
      let parts = pair.split(separator: "=", maxSplits: 1)
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
