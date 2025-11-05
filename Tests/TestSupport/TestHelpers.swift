import Foundation
import Mocker

@testable import ClerkKit

let mockBaseUrl = URL(string: "https://mock.clerk.accounts.dev")!

/// Test publishable key that decodes to mock.clerk.accounts.dev
let testPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

/// Configures Clerk for testing and replaces the API client with one that uses MockingURLProtocol.
/// This ensures that HTTP requests are intercepted by Mocker instead of reaching the real API.
///
/// This function should be called at the start of each test suite or test to ensure proper isolation.
@MainActor
func configureClerkForTesting() {
  // Configure Clerk with test publishable key
  Clerk.configure(publishableKey: testPublishableKey)

  // Replace the container with a mock container that uses MockingURLProtocol
  setupMockAPIClient()
}

/// Replaces the API client with MockingURLProtocol after Clerk.configure() creates the container.
/// This ensures that HTTP requests are intercepted by Mocker instead of reaching the real API.
@MainActor
func setupMockAPIClient() {
  let mockAPIClient = createMockAPIClient()

  // Replace the container with a mock container that uses the mock API client
  // InMemoryKeychain is now the default, so we don't need to pass it explicitly
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: mockAPIClient,
    telemetryCollector: Clerk.shared.dependencies.telemetryCollector
  )
}

/// Creates a mock API client configured to use MockingURLProtocol for testing.
@MainActor
func createMockAPIClient() -> APIClient {
  APIClient(baseURL: mockBaseUrl) { configuration in
    configuration.pipeline = .clerkDefault
    configuration.decoder = .clerkDecoder
    configuration.encoder = .clerkEncoder
    configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
    configuration.sessionConfiguration.httpAdditionalHeaders = [
      "Content-Type": "application/x-www-form-urlencoded",
      "clerk-api-version": Clerk.apiVersion,
      "x-ios-sdk-version": Clerk.sdkVersion,
      "x-mobile": "1"
    ]
  }
}

/// Configures Clerk for testing with custom mock services.
///
/// This function allows you to inject custom mock services (like `MockClientService`) to control
/// the behavior of service methods during testing. This is useful for testing specific scenarios
/// such as delays, errors, or custom return values.
///
/// Example:
/// ```swift
/// @Test
/// func testWithMockService() async throws {
///   let mockClientService = MockClientService()
///   mockClientService.getHandler = {
///     try? await Task.sleep(for: .seconds(1))
///     return Client.mock
///   }
///
///   configureClerkWithMockServices(clientService: mockClientService)
///   // ... test code
/// }
/// ```
///
/// - Parameters:
///   - clientService: Optional custom client service (defaults to real ClientService with mock API client).
///   - userService: Optional custom user service (defaults to real UserService with mock API client).
///   - signInService: Optional custom sign-in service (defaults to real SignInService with mock API client).
///   - signUpService: Optional custom sign-up service (defaults to real SignUpService with mock API client).
///   - sessionService: Optional custom session service (defaults to real SessionService with mock API client).
///   - passkeyService: Optional custom passkey service (defaults to real PasskeyService with mock API client).
///   - organizationService: Optional custom organization service (defaults to real OrganizationService with mock API client).
///   - environmentService: Optional custom environment service (defaults to real EnvironmentService with mock API client).
///   - clerkService: Optional custom clerk service (defaults to real ClerkService with mock API client).
///   - emailAddressService: Optional custom email address service (defaults to real EmailAddressService with mock API client).
///   - phoneNumberService: Optional custom phone number service (defaults to real PhoneNumberService with mock API client).
///   - externalAccountService: Optional custom external account service (defaults to real ExternalAccountService with mock API client).
@MainActor
func configureClerkWithMockServices(
  clientService: (any ClientServiceProtocol)? = nil,
  userService: (any UserServiceProtocol)? = nil,
  signInService: (any SignInServiceProtocol)? = nil,
  signUpService: (any SignUpServiceProtocol)? = nil,
  sessionService: (any SessionServiceProtocol)? = nil,
  passkeyService: (any PasskeyServiceProtocol)? = nil,
  organizationService: (any OrganizationServiceProtocol)? = nil,
  environmentService: (any EnvironmentServiceProtocol)? = nil,
  clerkService: (any ClerkServiceProtocol)? = nil,
  emailAddressService: (any EmailAddressServiceProtocol)? = nil,
  phoneNumberService: (any PhoneNumberServiceProtocol)? = nil,
  externalAccountService: (any ExternalAccountServiceProtocol)? = nil
) {
  // Configure Clerk with test publishable key (this creates initial dependencies)
  Clerk.configure(publishableKey: testPublishableKey)

  // Create mock API client
  let mockAPIClient = createMockAPIClient()

  // Get existing dependencies to preserve keychain and telemetry
  let existingDependencies = Clerk.shared.dependencies

  // Replace the container with a mock container that uses the mock API client and custom services
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: mockAPIClient,
    keychain: existingDependencies.keychain,
    telemetryCollector: existingDependencies.telemetryCollector,
    clientService: clientService,
    userService: userService,
    signInService: signInService,
    signUpService: signUpService,
    sessionService: sessionService,
    passkeyService: passkeyService,
    organizationService: organizationService,
    environmentService: environmentService,
    clerkService: clerkService,
    emailAddressService: emailAddressService,
    phoneNumberService: phoneNumberService,
    externalAccountService: externalAccountService
  )
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
