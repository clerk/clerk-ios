import ConcurrencyExtras
import FactoryKit
import Foundation
import Get
import Mocker
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct NetworkingPipelineTests {

  @Test
  @MainActor
  func testRequestMiddlewareAppliesProxyHeadersAndQuery() async throws {
    defer { Mocker.removeAll() }
    Clerk.shared.settings = .init(debugMode: true, proxyUrl: "https://clerk.mock.dev/__clerk")
    TestContainer.reset()
    Clerk.shared.client = .mock
    try Container.shared.keychain().set("device-token", forKey: "clerkDeviceToken")

    let capturedRequest = LockIsolated<URLRequest?>(nil)

    var mock = Mock(
      url: mockBaseUrl.appending(path: "/__clerk/v1/client"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: try JSONEncoder.clerkEncoder.encode(Client.mock)
      ]
    )
    mock.onRequestHandler = OnRequestHandler { request in
      capturedRequest.setValue(request)
    }
    mock.register()

    let request = Request<Client>(
      path: "/v1/client",
      method: .get
    )

    _ = try await Container.shared.apiClient().send(request).value

    guard let requestSent = capturedRequest.value else {
      Issue.record("Expected request to be captured")
      return
    }

    let components = URLComponents(url: requestSent.url!, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []
    let query = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

    #expect(components?.path == "/__clerk/v1/client")
    #expect(query["_is_native"] == "true")
    #expect(requestSent.value(forHTTPHeaderField: "Authorization") == "device-token")
    #expect(requestSent.value(forHTTPHeaderField: "x-clerk-client-id") == Clerk.shared.client?.id)
    #expect(requestSent.value(forHTTPHeaderField: "x-native-device-id") == deviceID)
  }

  @Test
  @MainActor
  func testResponseMiddlewareUpdatesClientAndKeychain() async throws {
    defer {
      Clerk.shared.client = nil
      Mocker.removeAll()
    }
    let expectedClient = Client.mock
    Clerk.shared.settings = .init()
    TestContainer.reset()
    let mock = Mock(
      url: mockBaseUrl.appending(path: "/v1/client"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: try JSONEncoder.clerkEncoder.encode(expectedClient)
      ],
      additionalHeaders: [
        "Authorization": "new-device-token"
      ]
    )
    mock.register()

    let request = Request<Client>(
      path: "/v1/client",
      method: .get
    )

    _ = try await Container.shared.apiClient().send(request).value
    try await Task.sleep(nanoseconds: 5_000_000) // allow async client update

    let storedToken = try Container.shared.keychain().string(forKey: "clerkDeviceToken")
    #expect(storedToken == "new-device-token")
    #expect(Clerk.shared.client?.id == expectedClient.id)
  }

  @Test
  @MainActor
  func testErrorMiddlewareThrowsClerkAPIError() async throws {
    defer { Mocker.removeAll() }
    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "authentication_invalid",
          message: "Invalid auth",
          longMessage: "Authentication is invalid",
          meta: nil,
          clerkTraceId: nil
        )
      ],
      clerkTraceId: "trace-id"
    )

    TestContainer.reset()

    let mock = Mock(
      url: mockBaseUrl.appending(path: "/v1/client"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 401,
      data: [
        .get: try JSONEncoder.clerkEncoder.encode(errorResponse)
      ]
    )
    mock.register()

    let request = Request<Client>(
      path: "/v1/client",
      method: .get
    )

    do {
      _ = try await Container.shared.apiClient().send(request).value
      Issue.record("Expected send to throw")
    } catch let error as ClerkAPIError {
      #expect(error.code == "authentication_invalid")
      #expect(error.clerkTraceId == "trace-id")
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  @Test
  func testURLEncodedFormEncoderMiddlewareEncodesBody() async throws {
    struct Payload: Encodable {
      let firstName: String
      let lastName: String
    }

    var request = URLRequest(url: mockBaseUrl)
    request.httpBody = try JSONEncoder.clerkEncoder.encode(Payload(firstName: "Ada", lastName: "Lovelace"))

    try await ClerkURLEncodedFormEncoderMiddleware().prepare(&request)

    let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8)
    #expect(bodyString != nil)

    let components = URLComponents(string: "?\(bodyString!)")
    let items = components?.queryItems ?? []
    let dictionary = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })

    #expect(dictionary["first_name"] == "Ada")
    #expect(dictionary["last_name"] == "Lovelace")
  }

  @Test
  @MainActor
  func testAuthEventEmitterMiddlewareEmitsSignInCompleted() async throws {
    defer {
      Clerk.shared.authEventEmitter.finish()
      Mocker.removeAll()
    }

    TestContainer.reset()

    let eventTask = Task { @MainActor () -> AuthEvent? in
      var iterator = Clerk.shared.authEventEmitter.events.makeAsyncIterator()
      return await iterator.next()
    }

    let signInComplete = SignIn(
      id: "signin_1",
      status: .complete,
      supportedIdentifiers: nil,
      identifier: nil,
      supportedFirstFactors: nil,
      supportedSecondFactors: nil,
      firstFactorVerification: nil,
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: "sess_1"
    )

    let mock = Mock(
      url: mockBaseUrl.appending(path: "/v1/client/sign_ins/complete"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: try JSONEncoder.clerkEncoder.encode(ClientResponse(response: signInComplete, client: .mock))
      ]
    )
    mock.register()

    let request = Request<ClientResponse<SignIn>>(
      path: "/v1/client/sign_ins/complete",
      method: .get
    )
    _ = try await Container.shared.apiClient().send(request).value

    let event = await eventTask.value
    guard case let .signInCompleted(signIn)? = event else {
      Issue.record("Expected signInCompleted event")
      return
    }
    #expect(signIn.id == signInComplete.id)
  }

  @Test
  @MainActor
  func testAuthEventEmitterMiddlewareEmitsSignUpCompleted() async throws {
    defer {
      Clerk.shared.authEventEmitter.finish()
      Mocker.removeAll()
    }

    TestContainer.reset()

    let eventTask = Task { @MainActor () -> [AuthEvent] in
      var iterator = Clerk.shared.authEventEmitter.events.makeAsyncIterator()
      var events: [AuthEvent] = []
      while events.count < 2, let event = await iterator.next() {
        events.append(event)
      }
      return events
    }

    let signUpComplete = SignUp(
      id: "signup_1",
      status: .complete,
      requiredFields: [],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [],
      verifications: [:],
      username: nil,
      emailAddress: nil,
      phoneNumber: nil,
      web3Wallet: nil,
      passwordEnabled: true,
      firstName: nil,
      lastName: nil,
      unsafeMetadata: nil,
      createdSessionId: "sess_2",
      createdUserId: "user_1",
      abandonAt: Date()
    )

    let mock = Mock(
      url: mockBaseUrl.appending(path: "/v1/client/sign_ups/complete"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: try JSONEncoder.clerkEncoder.encode(ClientResponse(response: signUpComplete, client: .mock))
      ]
    )
    mock.register()

    let request = Request<ClientResponse<SignUp>>(
      path: "/v1/client/sign_ups/complete",
      method: .post
    )
    let response = try await Container.shared.apiClient().send(request).value
    #expect(response.response.status == .complete)

    let events = await eventTask.value
    #expect(events.contains { event in
      if case let .signUpCompleted(signUp) = event {
        return signUp.id == signUpComplete.id
      }
      return false
    })
  }

  @Test
  @MainActor
  func testAuthEventEmitterMiddlewareEmitsSessionSignedOut() async throws {
    defer {
      Clerk.shared.authEventEmitter.finish()
      Mocker.removeAll()
    }

    TestContainer.reset()

    let eventTask = Task { @MainActor () -> AuthEvent? in
      var iterator = Clerk.shared.authEventEmitter.events.makeAsyncIterator()
      return await iterator.next()
    }

    let sessionRemoved = Session(
      id: "session_1",
      status: .removed,
      expireAt: Date(),
      abandonAt: Date(),
      lastActiveAt: Date(),
      latestActivity: nil,
      lastActiveOrganizationId: nil,
      actor: nil,
      user: nil,
      publicUserData: nil,
      createdAt: Date(),
      updatedAt: Date(),
      tasks: nil,
      lastActiveToken: nil
    )

    let mock = Mock(
      url: mockBaseUrl.appending(path: "/v1/client/sessions/sign_out"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: try JSONEncoder.clerkEncoder.encode(ClientResponse(response: sessionRemoved, client: .mock))
      ]
    )
    mock.register()

    let request = Request<ClientResponse<Session>>(
      path: "/v1/client/sessions/sign_out",
      method: .post
    )
    _ = try await Container.shared.apiClient().send(request).value

    let event = await eventTask.value
    guard case let .signedOut(session)? = event else {
      Issue.record("Expected signedOut event")
      return
    }
    #expect(session.id == sessionRemoved.id)
  }

  @Test
  @MainActor
  func testInvalidAuthMiddlewareTriggersClientSync() async throws {
    defer {
      Clerk.shared.client = nil
      Mocker.removeAll()
    }

    TestContainer.reset()

    let clientFetchPerformed = LockIsolated(false)

    var clientMock = Mock(
      url: mockBaseUrl.appending(path: "/v1/client"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: try JSONEncoder.clerkEncoder.encode(Client.mock)
      ]
    )
    clientMock.onRequestHandler = OnRequestHandler { _ in
      clientFetchPerformed.setValue(true)
    }
    clientMock.register()

    let errorResponse = ClerkErrorResponse(
      errors: [
        ClerkAPIError(
          code: "authentication_invalid",
          message: "Invalid auth",
          longMessage: "Authentication is invalid",
          meta: nil,
          clerkTraceId: "trace"
        )
      ],
      clerkTraceId: "trace"
    )

    let failingMock = Mock(
      url: mockBaseUrl.appending(path: "/v1/sessions"),
      ignoreQuery: true,
      contentType: .json,
      statusCode: 401,
      data: [
        .get: try JSONEncoder.clerkEncoder.encode(errorResponse)
      ]
    )
    failingMock.register()

    let request = Request<Client>(
      path: "/v1/sessions",
      method: .get
    )

    do {
      _ = try await Container.shared.apiClient().send(request).value
      Issue.record("Expected authentication_invalid error")
    } catch let error as ClerkAPIError {
      #expect(error.code == "authentication_invalid")
    }

    try await Task.sleep(nanoseconds: 10_000_000)
    #expect(clientFetchPerformed.value)
  }

  @Test
  func testDeviceAssertionRetryMiddlewareInvokesAssertionHandler() async throws {
    let invocationCount = LockIsolated(0)
    let middleware = ClerkDeviceAssertionRetryMiddleware {
      invocationCount.withValue { $0 += 1 }
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let task = URLSession.shared.dataTask(with: request)
    let error = ClerkAPIError(
      code: "requires_assertion",
      message: nil,
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    let shouldRetry = try await middleware.shouldRetry(task, error: error, attempts: 1)

    #expect(shouldRetry)
    #expect(invocationCount.value == 1)
  }

  @Test
  func testDeviceAssertionRetryMiddlewareSkipsOnSubsequentAttempts() async throws {
    let invocationCount = LockIsolated(0)
    let middleware = ClerkDeviceAssertionRetryMiddleware {
      invocationCount.withValue { $0 += 1 }
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let task = URLSession.shared.dataTask(with: request)
    let error = ClerkAPIError(
      code: "requires_assertion",
      message: nil,
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    let shouldRetry = try await middleware.shouldRetry(task, error: error, attempts: 2)

    #expect(!shouldRetry)
    #expect(invocationCount.value == 0)
  }

  @Test
  func testDeviceAssertionRetryMiddlewareSkipsForNonMatchingError() async throws {
    let invocationCount = LockIsolated(0)
    let middleware = ClerkDeviceAssertionRetryMiddleware {
      invocationCount.withValue { $0 += 1 }
    }

    let request = URLRequest(url: URL(string: "https://example.com")!)
    let task = URLSession.shared.dataTask(with: request)
    let error = URLError(.badServerResponse)

    let shouldRetry = try await middleware.shouldRetry(task, error: error, attempts: 1)

    #expect(!shouldRetry)
    #expect(invocationCount.value == 0)
  }

  @Test
  func testRateLimitRetryMiddlewareRetriesOnStatus429() async throws {
    let delay = LockIsolated<UInt64>(0)
    let middleware = ClerkRateLimitRetryMiddleware { nanos in
      delay.setValue(nanos)
    }

    let url = URL(string: "https://example.com")!
    let response = HTTPURLResponse(
      url: url,
      statusCode: 429,
      httpVersion: nil,
      headerFields: ["Retry-After": "1"]
    )!

    let task = URLSessionTaskMock(
      request: URLRequest(url: url),
      response: response
    )

    let shouldRetry = try await middleware.shouldRetry(task, error: ClerkAPIError.mock, attempts: 1)

    #expect(shouldRetry)
    #expect(delay.value >= 100_000_000) // >= 100ms
  }

  @Test
  func testRateLimitRetryMiddlewareSkipsAfterFirstRetry() async throws {
    let delay = LockIsolated<UInt64>(0)
    let middleware = ClerkRateLimitRetryMiddleware { nanos in
      delay.setValue(nanos)
    }

    let url = URL(string: "https://example.com")!
    let response = HTTPURLResponse(
      url: url,
      statusCode: 429,
      httpVersion: nil,
      headerFields: ["Retry-After": "1"]
    )!
    let task = URLSessionTaskMock(
      request: URLRequest(url: url),
      response: response
    )

    let shouldRetry = try await middleware.shouldRetry(task, error: ClerkAPIError.mock, attempts: 2)

    #expect(!shouldRetry)
    #expect(delay.value == 0)
  }

  @Test
  func testRateLimitRetryMiddlewareRetriesOnNetworkError() async throws {
    let delay = LockIsolated<UInt64>(0)
    let middleware = ClerkRateLimitRetryMiddleware { nanos in
      delay.setValue(nanos)
    }

    let url = URL(string: "https://example.com")!
    let task = URLSessionTaskMock(
      request: URLRequest(url: url),
      response: nil
    )

    let shouldRetry = try await middleware.shouldRetry(task, error: URLError(.timedOut), attempts: 1)

    #expect(shouldRetry)
    #expect(delay.value == 500_000_000) // default 0.5s
  }

}

// MARK: - Helpers

private final class URLSessionTaskMock: URLSessionTask {
  private let storedRequest: URLRequest?
  private let storedResponse: URLResponse?

  override var currentRequest: URLRequest? { storedRequest }
  override var originalRequest: URLRequest? { storedRequest }
  override var response: URLResponse? { storedResponse }

  init(request: URLRequest?, response: URLResponse?) {
    self.storedRequest = request
    self.storedResponse = response
    super.init()
  }
}

extension URLSessionTaskMock: @unchecked Sendable {}
