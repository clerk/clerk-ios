@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkAuthEventEmitterResponseMiddlewareTests {
  @Test
  func validateEmitsSignInCompletedOnceAfterClientAcceptance() async throws {
    let clerk = try makeIdentityClerk()
    let pipeline = authResponsePipeline(for: clerk)
    var client = Client.mock
    client.id = "client-sign-in"
    let eventStream = clerk.auth.events

    try await pipeline.validate(
      signInResponse,
      data: signInResponseData(
        object: "sign_in_attempt",
        status: "complete",
        client: client
      ),
      for: request(signInRequest, sequence: 1, clerk: clerk)
    )
    clerk.auth.send(.accountDeleted)

    let events = await completionEventsBeforeSentinel(from: eventStream)
    let event = try #require(events.first)
    #expect(events.count == 1)
    #expect(clerk.client?.id == client.id)

    switch event {
    case .signInCompleted(let signIn):
      #expect(signIn.id == "sia_test")
      #expect(signIn.status == .complete)
      #expect(signIn.createdSessionId == "sess_test")
    default:
      Issue.record("Expected signInCompleted event but received \(String(describing: event))")
    }
  }

  @Test
  func validateEmitsSignUpCompletedOnceAfterClientAcceptance() async throws {
    let clerk = try makeIdentityClerk()
    let pipeline = authResponsePipeline(for: clerk)
    var client = Client.mock
    client.id = "client-sign-up"
    let eventStream = clerk.auth.events

    try await pipeline.validate(
      signUpResponse,
      data: signUpResponseData(
        object: "sign_up_attempt",
        status: "complete",
        client: client
      ),
      for: request(signUpRequest, sequence: 1, clerk: clerk)
    )
    clerk.auth.send(.accountDeleted)

    let events = await completionEventsBeforeSentinel(from: eventStream)
    let event = try #require(events.first)
    #expect(events.count == 1)
    #expect(clerk.client?.id == client.id)

    switch event {
    case .signUpCompleted(let signUp):
      #expect(signUp.id == "su_test")
      #expect(signUp.status == .complete)
      #expect(signUp.createdSessionId == "sess_test")
      #expect(signUp.createdUserId == "user_test")
    default:
      Issue.record("Expected signUpCompleted event but received \(String(describing: event))")
    }
  }

  @Test
  func validateDoesNotEmitCompletionForAStaleResponse() async throws {
    let clerk = try makeIdentityClerk()
    var currentClient = Client.mock
    currentClient.id = "current-client"
    try await clerk.identityController.applyNetworkResponse(
      ClientSyncResponseContext(
        update: .client(currentClient),
        deviceTokenUpdate: .absent,
        requestDeviceToken: "token",
        baseGeneration: nil,
        serverDate: nil,
        isCanonicalClientRequest: false,
        clientResponseGeneration: clerk.clientResponseGeneration,
        responseSequence: 2
      )
    )

    let pipeline = authResponsePipeline(for: clerk)
    var staleClient = Client.mock
    staleClient.id = "stale-client"
    let eventStream = clerk.auth.events

    try await pipeline.validate(
      signInResponse,
      data: signInResponseData(
        object: "sign_in_attempt",
        status: "complete",
        client: staleClient
      ),
      for: request(signInRequest, sequence: 1, clerk: clerk)
    )
    clerk.auth.send(.accountDeleted)

    let events = await completionEventsBeforeSentinel(from: eventStream)
    #expect(events.isEmpty)
    #expect(clerk.client?.id == currentClient.id)
  }

  @Test
  func validateDoesNotEmitAuthEventForIncompleteSignInAttempt() async throws {
    let clerk = Clerk()
    let middleware = ClerkAuthEventEmitterResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    let event = try await captureNextAuthEvent(from: clerk) {
      try await middleware.validate(
        signInResponse,
        data: signInResponseData(object: "sign_in_attempt", status: "needs_second_factor"),
        for: signInRequest
      )
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  @Test
  func validateDoesNotEmitAuthEventForIncompleteSignUpAttempt() async throws {
    let clerk = Clerk()
    let middleware = ClerkAuthEventEmitterResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    let event = try await captureNextAuthEvent(from: clerk) {
      try await middleware.validate(
        signUpResponse,
        data: signUpResponseData(object: "sign_up_attempt", status: "missing_requirements"),
        for: signUpRequest
      )
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  @Test
  func validateDoesNotEmitAuthEventForAbandonedSignUpAttempt() async throws {
    let clerk = Clerk()
    let middleware = ClerkAuthEventEmitterResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    let event = try await captureNextAuthEvent(from: clerk) {
      try await middleware.validate(
        signUpResponse,
        data: signUpResponseData(object: "sign_up_attempt", status: "abandoned"),
        for: signUpRequest
      )
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  @Test
  func validateEmitsSignedOutForRemovedSessionResponse() async throws {
    let clerk = Clerk()
    let middleware = ClerkAuthEventEmitterResponseMiddleware(runtimeScope: .current(clerkProvider: { clerk }))

    let capturedEvent = try await captureNextAuthEvent(from: clerk) {
      try await middleware.validate(
        sessionRemovalResponse,
        data: sessionResponseData(object: "session", status: "removed"),
        for: sessionRemovalRequest
      )
    }

    let event = try #require(capturedEvent)

    switch event {
    case .signedOut(let session):
      #expect(session.id == "sess_removed")
      #expect(session.status == .removed)
    default:
      Issue.record("Expected signedOut event but received \(String(describing: event))")
    }
  }

  private let signInRequest = URLRequest(url: URL(string: "https://example.com/v1/client/sign_ins")!)
  private let signInResponse = HTTPURLResponse(
    url: URL(string: "https://example.com/v1/client/sign_ins")!,
    statusCode: 200,
    httpVersion: nil,
    headerFields: nil
  )!

  private let signUpRequest = URLRequest(url: URL(string: "https://example.com/v1/client/sign_ups")!)
  private let signUpResponse = HTTPURLResponse(
    url: URL(string: "https://example.com/v1/client/sign_ups")!,
    statusCode: 200,
    httpVersion: nil,
    headerFields: nil
  )!

  private let sessionRemovalRequest = URLRequest(url: URL(string: "https://example.com/v1/client/sessions/sess_removed/remove")!)
  private let sessionRemovalResponse = HTTPURLResponse(
    url: URL(string: "https://example.com/v1/client/sessions/sess_removed/remove")!,
    statusCode: 200,
    httpVersion: nil,
    headerFields: nil
  )!

  private func captureNextAuthEvent(
    from clerk: Clerk,
    timeout: Duration = .milliseconds(250),
    operation: () async throws -> Void
  ) async throws -> AuthEvent? {
    let captured = LockIsolated<AuthEvent?>(nil)
    var listener: Task<Void, Never>?
    await withCheckedContinuation { (ready: CheckedContinuation<Void, Never>) in
      listener = Task { @MainActor in
        var iterator = clerk.auth.events.makeAsyncIterator()
        ready.resume()
        if let event = await iterator.next() {
          captured.setValue(event)
        }
      }
    }
    defer { listener?.cancel() }

    try await operation()

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if let event = captured.value {
        return event
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    return captured.value
  }

  private func authResponsePipeline(for clerk: Clerk) -> NetworkingPipeline {
    NetworkingPipeline(responseMiddleware: [
      ClerkClientSyncResponseMiddleware(runtimeScope: clerk.runtimeScope),
      ClerkAuthEventEmitterResponseMiddleware(runtimeScope: clerk.runtimeScope),
    ])
  }

  private func makeIdentityClerk() throws -> Clerk {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    return clerk
  }

  private func request(
    _ request: URLRequest,
    sequence: Int,
    clerk: Clerk
  ) -> URLRequest {
    var request = request
    request.setClerkRequestSequence(sequence)
    request.setClerkRequestDeviceToken("token")
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)
    return request
  }

  private nonisolated func completionEventsBeforeSentinel(
    from stream: AsyncStream<AuthEvent>
  ) async -> [AuthEvent] {
    var events: [AuthEvent] = []
    for await event in stream {
      switch event {
      case .signInCompleted, .signUpCompleted:
        events.append(event)
      case .accountDeleted:
        return events
      default:
        continue
      }
    }
    return events
  }

  private func signInResponseData(
    object: String,
    status: String,
    client: Client? = nil
  ) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(Envelope(
      response: SignInResponsePayload(
        object: object,
        id: "sia_test",
        status: status,
        createdSessionId: "sess_test"
      ),
      client: client
    ))
  }

  private func signUpResponseData(
    object: String,
    status: String,
    client: Client? = nil
  ) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(Envelope(
      response: SignUpResponsePayload(
        object: object,
        id: "su_test",
        status: status,
        requiredFields: [],
        optionalFields: [],
        missingFields: [],
        unverifiedFields: [],
        verifications: [:],
        passwordEnabled: true,
        createdSessionId: "sess_test",
        createdUserId: "user_test",
        abandonAt: Date(timeIntervalSince1970: 1_774_364_830)
      ),
      client: client
    ))
  }

  private func sessionResponseData(object: String, status: String) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(Envelope(
      response: SessionResponsePayload(
        object: object,
        id: "sess_removed",
        status: status,
        expireAt: Date(timeIntervalSince1970: 1_774_364_830),
        abandonAt: Date(timeIntervalSince1970: 1_774_364_830),
        lastActiveAt: Date(timeIntervalSince1970: 1_774_364_830),
        createdAt: Date(timeIntervalSince1970: 1_774_364_830),
        updatedAt: Date(timeIntervalSince1970: 1_774_364_830)
      ),
      client: nil
    ))
  }
}

private struct Envelope<Response: Codable>: Codable {
  let response: Response
  let client: Client?
}

private struct SignInResponsePayload: Codable {
  let object: String
  let id: String
  let status: String
  let createdSessionId: String?
}

private struct SignUpResponsePayload: Codable {
  let object: String
  let id: String
  let status: String
  let requiredFields: [String]
  let optionalFields: [String]
  let missingFields: [String]
  let unverifiedFields: [String]
  let verifications: [String: Verification?]
  let passwordEnabled: Bool
  let createdSessionId: String?
  let createdUserId: String?
  let abandonAt: Date
}

private struct SessionResponsePayload: Codable {
  let object: String
  let id: String
  let status: String
  let expireAt: Date
  let abandonAt: Date
  let lastActiveAt: Date
  let createdAt: Date
  let updatedAt: Date
}
