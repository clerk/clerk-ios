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
  func completedSignUpResponseEmitsSignUpCompleted() async throws {
    try await withMainSerialExecutor {
      let middleware = ClerkAuthEventEmitterResponseMiddleware()
      let fixture = try requestResponseFixture(path: "/v1/client/sign_ups")

      var signUp = SignUp.mock
      signUp.status = .complete
      let payload = try JSONEncoder.clerkEncoder.encode(
        ClientResponse<SignUp>(response: signUp, client: nil)
      )

      let eventStream = Clerk.shared.auth.events

      try await middleware.validate(fixture.response, data: payload, for: fixture.request)
      let event = await waitForAuthEvent(in: eventStream)

      let emittedEvent = try #require(event)
      switch emittedEvent {
      case .signUpCompleted(let emittedSignUp):
        #expect(emittedSignUp.id == signUp.id)
      default:
        Issue.record("Expected .signUpCompleted for a completed sign-up payload.")
      }
    }
  }

  @Test
  func completedSignInResponseEmitsSignInCompleted() async throws {
    try await withMainSerialExecutor {
      let middleware = ClerkAuthEventEmitterResponseMiddleware()
      let fixture = try requestResponseFixture(path: "/v1/client/sign_ins")

      var signIn = SignIn.mock
      signIn.status = .complete
      let payload = try JSONEncoder.clerkEncoder.encode(
        ClientResponse<SignIn>(response: signIn, client: nil)
      )

      let eventStream = Clerk.shared.auth.events

      try await middleware.validate(fixture.response, data: payload, for: fixture.request)
      let event = await waitForAuthEvent(in: eventStream)

      let emittedEvent = try #require(event)
      switch emittedEvent {
      case .signInCompleted(let emittedSignIn):
        #expect(emittedSignIn.id == signIn.id)
      default:
        Issue.record("Expected .signInCompleted for a completed sign-in payload.")
      }
    }
  }

  private func waitForAuthEvent(in stream: AsyncStream<AuthEvent>) async -> AuthEvent? {
    await withTaskGroup(of: AuthEvent?.self) { group in
      group.addTask {
        var events = stream.makeAsyncIterator()
        return await events.next()
      }
      group.addTask {
        try? await Task.sleep(for: .milliseconds(500))
        return nil
      }
      defer { group.cancelAll() }
      return await group.next() ?? nil
    }
  }

  private func requestResponseFixture(path: String) throws -> (request: URLRequest, response: HTTPURLResponse) {
    let requestURL = try #require(URL(string: "https://example.com\(path)"))
    let request = URLRequest(url: requestURL)
    let response = try #require(HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    ))
    return (request: request, response: response)
  }
}
