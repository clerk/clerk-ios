@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct AuthViewTests {
  @Test
  func initializerStoresTheCompletionHandler() {
    var receivedSessionId: String?
    let view = AuthView { session in
      receivedSessionId = session.id
    }
    let session = Session.mock

    view.onCompletion(session)

    #expect(receivedSessionId == session.id)
  }

  @Test
  func configurationModifiersPreserveTheCompletionHandler() {
    var receivedSessionId: String?
    let view = AuthView { session in
      receivedSessionId = session.id
    }
    let configuredView = view.initialIdentifier("test@example.com")
    let session = Session.mock

    configuredView.onCompletion(session)

    #expect(receivedSessionId == session.id)
  }
}
