//
//  ClerkAuthEventEmitterResponseMiddlewareTests.swift
//  Clerk
//

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
  func emitsSignUpCompletedEvent() async throws {
    var signUp = SignUp.mock
    signUp.status = .complete

    let jsonData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse(
        response: signUp,
        client: Client.mockSignedOut
      )
    )

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    // Listen for events
    let eventTask = Task {
      for await event in Clerk.shared.auth.events {
        if case .signUpCompleted(let receivedSignUp) = event {
          return receivedSignUp
        }
      }
      return nil
    }

    try await middleware.validate(response, data: jsonData, for: request)

    let receivedSignUp = await eventTask.value
    #expect(receivedSignUp?.id == signUp.id)
    #expect(receivedSignUp?.status == .complete)
  }

  @Test
  func emitsSignInCompletedEvent() async throws {
    var signIn = SignIn.mock
    signIn.status = .complete

    let jsonData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse(
        response: signIn,
        client: Client.mockSignedOut
      )
    )

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    // Listen for events with timeout
    let eventTask = Task {
      for await event in Clerk.shared.auth.events {
        if case .signInCompleted(let receivedSignIn) = event {
          return receivedSignIn
        }
      }
      return nil
    }

    try await middleware.validate(response, data: jsonData, for: request)

    let receivedSignIn = await eventTask.value
    #expect(receivedSignIn?.id == signIn.id)
    #expect(receivedSignIn?.status == .complete)
  }

  @Test
  func emitsSignedOutEvent() async throws {
    var session = Session.mock
    session.status = .removed

    let jsonData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse(
        response: session,
        client: Client.mockSignedOut
      )
    )

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    // Listen for events
    let eventTask = Task {
      for await event in Clerk.shared.auth.events {
        if case .signedOut(let receivedSession) = event {
          return receivedSession
        }
      }
      return nil
    }

    try await middleware.validate(response, data: jsonData, for: request)

    let receivedSession = await eventTask.value
    #expect(receivedSession?.id == session.id)
    #expect(receivedSession?.status == .removed)
  }

  @Test
  func doesNotEmitEventForIncompleteSignUp() async throws {
    var signUp = SignUp.mock
    signUp.status = .missingRequirements

    let jsonData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse(
        response: signUp,
        client: Client.mockSignedOut
      )
    )

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    try await middleware.validate(response, data: jsonData, for: request)

    // No event should be emitted for incomplete sign-ups
  }

  @Test
  func doesNotEmitEventForIncompleteSignIn() async throws {
    var signIn = SignIn.mock
    signIn.status = .needsFirstFactor

    let jsonData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse(
        response: signIn,
        client: Client.mockSignedOut
      )
    )

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    try await middleware.validate(response, data: jsonData, for: request)

    // No event should be emitted for incomplete sign-ins
  }

  @Test
  func doesNotEmitEventForActiveSession() async throws {
    var session = Session.mock
    session.status = .active

    let jsonData = try JSONEncoder.clerkEncoder.encode(
      ClientResponse(
        response: session,
        client: Client.mockSignedOut
      )
    )

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    try await middleware.validate(response, data: jsonData, for: request)

    // No event should be emitted for active sessions
  }

  @Test
  func handlesInvalidJSONGracefully() async throws {
    let invalidData = Data([0x00, 0x01, 0x02])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    // Should not crash on invalid JSON
    try await middleware.validate(response, data: invalidData, for: request)
  }

  @Test
  func handlesUnknownObjectType() async throws {
    let jsonData = try JSONEncoder.clerkEncoder.encode([
      "response": [
        "object": "unknown_type",
        "id": "test123"
      ]
    ])

    let response = HTTPURLResponse(
      url: URL(string: "https://api.clerk.test")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let request = URLRequest(url: URL(string: "https://api.clerk.test")!)
    let middleware = ClerkAuthEventEmitterResponseMiddleware()

    // Should not crash on unknown object types
    try await middleware.validate(response, data: jsonData, for: request)
  }
}