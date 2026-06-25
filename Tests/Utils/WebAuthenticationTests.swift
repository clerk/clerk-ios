//
//  WebAuthenticationTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

// MARK: - WebAuthContinuationManager Tests

@Suite(.serialized)
struct WebAuthContinuationManagerTests {
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
  func completesSessionWithExplicitError() async {
    let manager = WebAuthContinuationManager()

    await #expect(throws: (any Error).self) {
      try await withCheckedThrowingContinuation { continuation in
        Task {
          await manager.setContinuation(continuation)
          let error = NSError(domain: "Test", code: -1)
          await manager.completeSession(with: nil, error: error)
        }
      } as URL
    }
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

@Suite(.serialized)
struct WebAuthenticationCleanupTests {
  @Test
  @MainActor
  func finishWithDeeplinkUrlClearsSessionBeforeCompletion() async throws {
    let url = try #require(URL(string: "https://example.com/callback"))

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
  @MainActor
  func cancelCurrentSessionClearsState() async {
    // After cancel, session state should be cleared.
    await WebAuthentication.cancelCurrentSession()
    #expect(WebAuthentication.hasActiveSession() == false)
  }
}
