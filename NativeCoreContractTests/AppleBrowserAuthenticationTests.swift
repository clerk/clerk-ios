#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct AppleBrowserAuthenticationTests {
  private let arguments: JSONValue = .object([
    "url": .string("https://example.com/oauth"),
    "callbackUrl": .string("app.clerk://oauth/callback"),
  ])

  @Test func failedStartResumesTheCallerAndAllowsTheNextSession() async throws {
    let probe = BrowserProbe()
    probe.startsSuccessfully = false
    let authentication = probe.authentication()
    do {
      _ = try await authentication.openBrowser("browser", arguments: arguments)
      Issue.record("Expected failed browser presentation")
    } catch let error as CoreError {
      #expect(error.code == "browser_presentation_failed")
    }
    probe.startsSuccessfully = true
    let next = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let session = await probe.session(number: 2)
    session.complete(with: URL(string: "app.clerk://oauth/callback?code=current"), error: nil)
    #expect(try await next.value == .object(["callbackUrl": .string("app.clerk://oauth/callback?code=current")]))
  }

  @Test func taskCancellationReleasesThePresenterAndIgnoresItsLateCallback() async throws {
    let probe = BrowserProbe()
    let authentication = probe.authentication()
    let first = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let obsolete = await probe.session(number: 1)
    first.cancel()
    await #expect(throws: CancellationError.self) { try await first.value }
    #expect(obsolete.cancelCallCount == 1)

    let second = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let current = await probe.session(number: 2)
    obsolete.complete(with: URL(string: "app.clerk://oauth/callback?code=obsolete"), error: nil)
    current.complete(with: URL(string: "app.clerk://oauth/callback?code=current"), error: nil)
    #expect(try await second.value == .object(["callbackUrl": .string("app.clerk://oauth/callback?code=current")]))
  }

  @Test func duplicateCompletionCannotCompleteTheFollowingSession() async throws {
    let probe = BrowserProbe()
    let authentication = probe.authentication()
    let first = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let completed = await probe.session(number: 1)
    completed.complete(with: URL(string: "app.clerk://oauth/callback?code=first"), error: nil)
    _ = try await first.value
    let second = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let current = await probe.session(number: 2)
    completed.complete(with: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
    current.complete(with: URL(string: "app.clerk://oauth/callback?code=current"), error: nil)
    #expect(try await second.value == .object(["callbackUrl": .string("app.clerk://oauth/callback?code=current")]))
  }

  @Test func competingCallDoesNotReplaceTheActiveSession() async throws {
    let probe = BrowserProbe()
    let authentication = probe.authentication()
    let first = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let current = await probe.session(number: 1)
    do {
      _ = try await authentication.openBrowser("browser", arguments: arguments)
      Issue.record("Expected an occupied presenter to reject another call")
    } catch let error as CoreError {
      #expect(error.code == "presentation_in_progress")
    }
    current.complete(with: URL(string: "app.clerk://oauth/callback?code=current"), error: nil)
    #expect(try await first.value == .object(["callbackUrl": .string("app.clerk://oauth/callback?code=current")]))
  }

  @Test func systemCancellationPreservesItsStructuredError() async throws {
    let probe = BrowserProbe()
    let authentication = probe.authentication()
    let pending = Task { try await authentication.openBrowser("browser", arguments: arguments) }
    let session = await probe.session(number: 1)
    session.complete(with: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
    do {
      _ = try await pending.value
      Issue.record("Expected system cancellation")
    } catch let error as CoreError {
      #expect(error.code == "user_cancelled")
    }
  }
}

@MainActor
private final class BrowserProbe {
  var startsSuccessfully = true
  private var sessions: [StubWebAuthenticationSession] = []
  private var waiter: CheckedContinuation<Void, Never>?
  private var requestedCount = 0

  func authentication() -> AppleAuthentication {
    AppleAuthentication(anchor: { preconditionFailure("The stub must not present native UI") }) { url, callback, completion in
      let session = StubWebAuthenticationSession(url: url, callbackURLScheme: callback.scheme,
                                                 completionHandler: completion, startResult: self.startsSuccessfully)
      self.sessions.append(session)
      if self.sessions.count == self.requestedCount, let waiter = self.waiter {
        self.waiter = nil
        waiter.resume()
      }
      return session
    }
  }

  func session(number: Int) async -> StubWebAuthenticationSession {
    if sessions.count >= number { return sessions[number - 1] }
    requestedCount = number
    await withCheckedContinuation { waiter = $0 }
    return sessions[number - 1]
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
