#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Testing

@MainActor
struct SignInPasskeyViewTests {
  @Test
  func cancelingAutomaticAuthenticationDelayPreventsPasskeyAttempt() async {
    let delayStarted = AsyncStream<Void>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    var delayStartedIterator = delayStarted.stream.makeAsyncIterator()
    var authenticationAttemptCount = 0

    let automaticAuthenticationTask = Task {
      await SignInPasskeyView.performAutomaticPasskeyAuthentication(
        delay: {
          delayStarted.continuation.yield()
          try await Task.sleep(for: .seconds(60))
        },
        authenticate: {
          authenticationAttemptCount += 1
        }
      )
    }

    _ = await delayStartedIterator.next()
    automaticAuthenticationTask.cancel()
    let didAuthenticate = await automaticAuthenticationTask.value
    delayStarted.continuation.finish()

    #expect(!didAuthenticate)
    #expect(authenticationAttemptCount == 0)
  }
}

#endif
