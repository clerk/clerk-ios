@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkAuthEventEmitterResponseMiddlewareTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func completedSignUpResponseEmitsSignUpCompleted() throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    var signUp = SignUp.mock
    signUp.status = .complete
    let payload = try JSONEncoder.clerkEncoder.encode(
      ClientResponse<SignUp>(response: signUp, client: nil)
    )

    let event = middleware.authEvent(from: payload)
    let emittedEvent = try #require(event)
    switch emittedEvent {
    case .signUpCompleted(let emittedSignUp):
      #expect(emittedSignUp.id == signUp.id)
    default:
      Issue.record("Expected .signUpCompleted for a completed sign-up payload.")
    }
  }

  @Test
  func completedSignInResponseEmitsSignInCompleted() throws {
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    var signIn = SignIn.mock
    signIn.status = .complete
    let payload = try JSONEncoder.clerkEncoder.encode(
      ClientResponse<SignIn>(response: signIn, client: nil)
    )

    let event = middleware.authEvent(from: payload)
    let emittedEvent = try #require(event)
    switch emittedEvent {
    case .signInCompleted(let emittedSignIn):
      #expect(emittedSignIn.id == signIn.id)
    default:
      Issue.record("Expected .signInCompleted for a completed sign-in payload.")
    }
  }
}
