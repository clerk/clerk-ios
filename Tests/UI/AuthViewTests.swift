@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct AuthViewTests {
  @Test
  func initializerStoresTheAuthCompleteHandler() {
    var receivedSessionId: String?
    let view = AuthView(onAuthComplete: { session in
      receivedSessionId = session.id
    })
    let session = Session.mock

    view.onAuthComplete(session)

    #expect(receivedSessionId == session.id)
  }

  @Test
  func configurationModifiersPreserveTheAuthCompleteHandler() {
    var receivedSessionId: String?
    let view = AuthView { session in
      receivedSessionId = session.id
    }
    let configuredView = view.initialIdentifier("test@example.com")
    let session = Session.mock

    configuredView.onAuthComplete(session)

    #expect(receivedSessionId == session.id)
  }
}
