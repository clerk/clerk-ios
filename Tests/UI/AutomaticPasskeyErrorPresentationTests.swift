#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct AutomaticPasskeyErrorPresentationTests {
  @Test
  func onlyAttemptStageIsPresented() {
    #expect(AuthStartView.shouldPresentAutomaticPasskeyError(at: .attemptingFirstFactor))
    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(at: .preparingFirstFactor))
    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(at: .requestingAuthorization))
  }
}

#endif
