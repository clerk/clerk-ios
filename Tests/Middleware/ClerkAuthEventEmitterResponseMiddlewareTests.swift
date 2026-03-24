@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkAuthEventEmitterResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func validateEmitsSignInCompletedForCompleteSignInResponse() async throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    let capturedEvent = try await captureNextAuthEvent {
      try await middleware.validate(response, data: signInResponseData(status: "complete"), for: request)
    }

    let event = try #require(capturedEvent)

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
  func validateEmitsSignUpCompletedForCompleteSignUpResponse() async throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    let capturedEvent = try await captureNextAuthEvent {
      try await middleware.validate(response, data: signUpResponseData(status: "complete"), for: request)
    }

    let event = try #require(capturedEvent)

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
  func validateDoesNotEmitSignInCompletedForIncompleteSignInAttempt() async throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    let event = try await captureNextAuthEvent {
      try await middleware.validate(response, data: signInResponseData(status: "needs_second_factor"), for: request)
    }

    if let event {
      Issue.record("Expected no auth event but received \(String(describing: event))")
    }
  }

  @Test
  func validateEmitsSignedOutForRemovedSessionResponse() async throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    let capturedEvent = try await captureNextAuthEvent {
      try await middleware.validate(response, data: sessionResponseData(status: "removed"), for: request)
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

  @Test
  func validatePrefersSignUpBeforeSignInWhenPayloadCanDecodeAsBoth() async throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    let capturedEvent = try await captureNextAuthEvent {
      try await middleware.validate(response, data: signUpResponseData(status: "complete"), for: request)
    }

    let event = try #require(capturedEvent)

    switch event {
    case .signUpCompleted:
      break
    default:
      Issue.record("Expected signUpCompleted event but received \(String(describing: event))")
    }
  }

  private let request = URLRequest(url: URL(string: "https://example.com/v1/client/sign_ins")!)
  private let response = HTTPURLResponse(
    url: URL(string: "https://example.com/v1/client/sign_ins")!,
    statusCode: 200,
    httpVersion: nil,
    headerFields: nil
  )!

  private func captureNextAuthEvent(
    timeout: Duration = .milliseconds(250),
    operation: () async throws -> Void
  ) async throws -> AuthEvent? {
    let captured = LockIsolated<AuthEvent?>(nil)
    let listener = Task { @MainActor in
      var iterator = Clerk.shared.auth.events.makeAsyncIterator()
      if let event = await iterator.next() {
        captured.setValue(event)
      }
    }
    defer { listener.cancel() }

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

  private func signInResponseData(status: String) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(Envelope(
      response: SignInResponsePayload(
        id: "sia_test",
        status: status,
        createdSessionId: "sess_test"
      )
    ))
  }

  private func signUpResponseData(status: String) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(Envelope(
      response: SignUpResponsePayload(
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
      )
    ))
  }

  private func sessionResponseData(status: String) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(Envelope(
      response: SessionResponsePayload(
        id: "sess_removed",
        status: status,
        expireAt: Date(timeIntervalSince1970: 1_774_364_830),
        abandonAt: Date(timeIntervalSince1970: 1_774_364_830),
        lastActiveAt: Date(timeIntervalSince1970: 1_774_364_830),
        createdAt: Date(timeIntervalSince1970: 1_774_364_830),
        updatedAt: Date(timeIntervalSince1970: 1_774_364_830)
      )
    ))
  }
}

private struct Envelope<Response: Codable>: Codable {
  let response: Response
}

private struct SignInResponsePayload: Codable {
  let id: String
  let status: String
  let createdSessionId: String?
}

private struct SignUpResponsePayload: Codable {
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
  let id: String
  let status: String
  let expireAt: Date
  let abandonAt: Date
  let lastActiveAt: Date
  let createdAt: Date
  let updatedAt: Date
}
