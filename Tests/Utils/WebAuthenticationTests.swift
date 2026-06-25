//
//  WebAuthenticationTests.swift
//

import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

// MARK: - WebAuthContinuationManager Tests

@MainActor
@Suite(.serialized)
struct WebAuthContinuationManagerTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func completesSessionWithURL() async throws {
    let manager = WebAuthContinuationManager()
    let expected = try #require(URL(string: "https://example.com/callback"))

    let result: URL = try await withCheckedThrowingContinuation { continuation in
      Task {
        await manager.setContinuation(continuation)
        await manager.completeSession(with: expected, error: nil)
      }
    }

    #expect(result == expected)
  }

  @Test
  func completesSessionWithError() async {
    let manager = WebAuthContinuationManager()

    await #expect(throws: ClerkClientError.self) {
      try await withCheckedThrowingContinuation { continuation in
        Task {
          await manager.setContinuation(continuation)
          await manager.completeSession(with: nil, error: nil)
        }
      } as URL
    }
  }

  @Test
  func completesSessionWithExplicitError() async throws {
    let manager = WebAuthContinuationManager()
    let expectedError = NSError(domain: "Test", code: -1)

    var thrownError: (any Error)?
    do {
      _ = try await withCheckedThrowingContinuation { continuation in
        Task {
          await manager.setContinuation(continuation)
          await manager.completeSession(with: nil, error: expectedError)
        }
      } as URL
    } catch {
      thrownError = error
    }

    let nsError = try #require(thrownError as? NSError)
    #expect(nsError.domain == "Test")
    #expect(nsError.code == -1)
  }

  @Test
  func cancelSessionIfNeededResumesCancellation() async {
    let manager = WebAuthContinuationManager()

    await #expect(throws: CancellationError.self) {
      try await withCheckedThrowingContinuation { continuation in
        Task {
          await manager.setContinuation(continuation)
          await manager.cancelSessionIfNeeded()
        }
      } as URL
    }
  }

  @Test
  func duplicateCompletionIsIgnored() async throws {
    let manager = WebAuthContinuationManager()
    let expected = try #require(URL(string: "https://example.com/callback"))

    let result: URL = try await withCheckedThrowingContinuation { continuation in
      Task {
        await manager.setContinuation(continuation)
        await manager.completeSession(with: expected, error: nil)
        // Second call should be silently ignored (no crash).
        await manager.completeSession(with: nil, error: nil)
      }
    }

    #expect(result == expected)
  }
}

// MARK: - WebAuthentication State Cleanup Tests

@MainActor
@Suite(.serialized)
struct WebAuthenticationCleanupTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func finishWithDeeplinkUrlClearsSessionBeforeCompletion() async throws {
    let url = try #require(URL(string: "https://example.com/callback"))

    // Seed active session
    let dummySession = ASWebAuthenticationSession(url: url, callbackURLScheme: "test") { _, _ in }
    let auth = WebAuthentication(url: url)
    WebAuthentication.currentSession = dummySession
    WebAuthentication.currentAuthInstance = auth

    #expect(WebAuthentication.hasActiveSession() == true)

    // Simulate a pending auth session by running a continuation that
    // will be completed by `finishWithDeeplinkUrl`.
    let task = Task { @MainActor in
      try await withCheckedThrowingContinuation { continuation in
        Task {
          await WebAuthentication.continuationManager.setContinuation(continuation)

          // Trigger deeplink completion.
          WebAuthentication.finishWithDeeplinkUrl(url: url)
        }
      } as URL
    }

    let result = try await task.value
    #expect(result == url)

    // After the deeplink finishes, session state must already be cleared.
    #expect(WebAuthentication.hasActiveSession() == false)
  }

  @Test
  func cancelCurrentSessionClearsState() async throws {
    let url = try #require(URL(string: "https://example.com/callback"))

    // Seed active session
    let dummySession = ASWebAuthenticationSession(url: url, callbackURLScheme: "test") { _, _ in }
    let auth = WebAuthentication(url: url)
    WebAuthentication.currentSession = dummySession
    WebAuthentication.currentAuthInstance = auth

    #expect(WebAuthentication.hasActiveSession() == true)

    // Signal so we know the continuation has been set before we cancel.
    let (signal, signalContinuation) = AsyncStream<Void>.makeStream()

    let task = Task {
      await #expect(throws: CancellationError.self) {
        try await withCheckedThrowingContinuation { continuation in
          Task {
            await WebAuthentication.continuationManager.setContinuation(continuation)
            signalContinuation.yield()
            signalContinuation.finish()
          }
        } as URL
      }
    }

    // Wait until the continuation is actually set.
    for await _ in signal {}

    // After cancel, session state should be cleared.
    await WebAuthentication.cancelCurrentSession()
    #expect(WebAuthentication.hasActiveSession() == false)

    // Await the task to ensure the continuation completed with cancellation.
    _ = await task.result
  }
}
