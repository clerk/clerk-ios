//
//  WebAuthenticationTests.swift
//

#if canImport(AuthenticationServices)

import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct WebAuthenticationTests {
  @Test
  @MainActor
  func startFailureResumesCallerAndAllowsNextSession() async throws {
    let authURL = try #require(URL(string: "https://example.com/oauth"))
    var failingSession: StubWebAuthenticationSession?

    let failingAuthentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      #expect(url == authURL)
      #expect(callbackURLScheme == "test")

      let session = StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: false
      )
      failingSession = session
      return session
    }

    do {
      _ = try await failingAuthentication.start()
      Issue.record("Expected failed web authentication start to throw")
    } catch let error as ClerkClientError {
      #expect(error.message == "Unable to start web authentication session.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }

    #expect(failingSession?.startCallCount == 1)

    let callbackURL = try #require(URL(string: "test://callback?code=123"))
    let succeedingAuthentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: true,
        onStart: { session in
          session.complete(with: callbackURL, error: nil)
        }
      )
    }

    let result = try await succeedingAuthentication.start()
    #expect(result == callbackURL)
  }

  @Test
  @MainActor
  func cancelCurrentSessionCancelsSystemSessionAndResumesCaller() async throws {
    let authURL = try #require(URL(string: "https://example.com/oauth"))
    var session: StubWebAuthenticationSession?

    let authentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      let stub = StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: true
      )
      session = stub
      return stub
    }

    let task = Task { @MainActor in
      try await authentication.start()
    }

    for _ in 0 ..< 10 where session?.startCallCount != 1 {
      await Task.yield()
    }
    #expect(session?.startCallCount == 1)

    WebAuthentication.cancelCurrentSession()

    do {
      _ = try await task.value
      Issue.record("Expected active web authentication session to be cancelled")
    } catch is CancellationError {
      #expect(session?.cancelCallCount == 1)
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }
  }

  @Test
  @MainActor
  func staleCompletionAfterCancellationDoesNotCompleteNextSession() async throws {
    let authURL = try #require(URL(string: "https://example.com/oauth"))
    var firstSession: StubWebAuthenticationSession?

    let firstAuthentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      let stub = StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: true
      )
      firstSession = stub
      return stub
    }

    let firstTask = Task { @MainActor in
      try await firstAuthentication.start()
    }

    for _ in 0 ..< 10 where firstSession?.startCallCount != 1 {
      await Task.yield()
    }
    #expect(firstSession?.startCallCount == 1)

    WebAuthentication.cancelCurrentSession()
    await #expect(throws: CancellationError.self) {
      try await firstTask.value
    }

    var secondSession: StubWebAuthenticationSession?
    let secondAuthentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      let stub = StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: true
      )
      secondSession = stub
      return stub
    }

    let secondTask = Task { @MainActor in
      try await secondAuthentication.start()
    }

    for _ in 0 ..< 10 where secondSession?.startCallCount != 1 {
      await Task.yield()
    }
    #expect(secondSession?.startCallCount == 1)

    let staleURL = try #require(URL(string: "test://callback?code=stale"))
    firstSession?.complete(with: staleURL, error: nil)
    for _ in 0 ..< 10 {
      await Task.yield()
    }

    let callbackURL = try #require(URL(string: "test://callback?code=current"))
    secondSession?.complete(with: callbackURL, error: nil)

    let result = try await secondTask.value
    #expect(result == callbackURL)
  }

  @Test
  @MainActor
  func secondStartFailsWithoutOverwritingActiveSession() async throws {
    let authURL = try #require(URL(string: "https://example.com/oauth"))
    var activeSession: StubWebAuthenticationSession?

    let activeAuthentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      let stub = StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: true
      )
      activeSession = stub
      return stub
    }

    let activeTask = Task { @MainActor in
      try await activeAuthentication.start()
    }

    for _ in 0 ..< 10 where activeSession?.startCallCount != 1 {
      await Task.yield()
    }
    #expect(activeSession?.startCallCount == 1)

    let competingAuthentication = WebAuthentication(
      url: authURL,
      callbackURLScheme: "test"
    ) { url, callbackURLScheme, completionHandler in
      StubWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackURLScheme,
        completionHandler: completionHandler,
        startResult: true
      )
    }

    do {
      _ = try await competingAuthentication.start()
      Issue.record("Expected competing web authentication session to throw")
    } catch let error as ClerkClientError {
      #expect(error.message == "A web authentication session is already in progress.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }

    let callbackURL = try #require(URL(string: "test://callback?code=current"))
    activeSession?.complete(with: callbackURL, error: nil)
    let result = try await activeTask.value
    #expect(result == callbackURL)
  }
}

private final class StubWebAuthenticationSession: ASWebAuthenticationSession {
  private let completionHandler: ASWebAuthenticationSession.CompletionHandler
  private let startResult: Bool
  private let onStart: (StubWebAuthenticationSession) -> Void

  private(set) var startCallCount = 0
  private(set) var cancelCallCount = 0

  init(
    url: URL,
    callbackURLScheme: String?,
    completionHandler: @escaping ASWebAuthenticationSession.CompletionHandler,
    startResult: Bool,
    onStart: @escaping (StubWebAuthenticationSession) -> Void = { _ in }
  ) {
    self.completionHandler = completionHandler
    self.startResult = startResult
    self.onStart = onStart
    super.init(
      url: url,
      callbackURLScheme: callbackURLScheme,
      completionHandler: completionHandler
    )
  }

  override func start() -> Bool {
    startCallCount += 1
    onStart(self)
    return startResult
  }

  override func cancel() {
    cancelCallCount += 1
  }

  func complete(with url: URL?, error: (any Error)?) {
    completionHandler(url, error)
  }
}

#endif
