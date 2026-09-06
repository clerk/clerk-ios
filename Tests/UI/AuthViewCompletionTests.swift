@testable import ClerkKitUI
import Testing

@MainActor
struct AuthViewCompletionTests {
  @Test
  func acceptsAParameterlessCompletionCallback() {
    var completionCount = 0
    let authView = AuthView {
      completionCount += 1
    }

    #expect(completionCount == 0)
    authView.onAuthComplete()
    #expect(completionCount == 1)
  }

  @Test
  func configurationModifiersPreserveTheCompletionCallback() {
    var completionCount = 0
    let authView = AuthView(
      mode: .signUp,
      isDismissible: false,
      onAuthComplete: {
        completionCount += 1
      }
    )
    .initialIdentifier("person@example.com")
    .initialFirstName("First")
    .initialLastName("Last")
    .lockPrefilledFields()
    .persistsIdentifiers(false)
    .unsafeMetadata(["source": "test"])

    #expect(authView.authState.mode == .signUp)
    #expect(authView.isDismissible == false)
    authView.onAuthComplete()
    #expect(completionCount == 1)
  }

  @Test
  func preservesTheExistingTwoArgumentInitializerFunction() {
    let factory: (AuthView.Mode, Bool) -> AuthView = AuthView.init

    let authView = factory(.signIn, false)

    #expect(authView.authState.mode == .signIn)
    #expect(authView.isDismissible == false)
  }

  @Test
  func finishesOnlyWhenDismissibleAndJSSessionIsActive() {
    let active = AuthView.JSSessionSnapshot(id: "sess_1", status: .active)

    #expect(
      !AuthView.shouldFinishForJSSession(isDismissible: false, session: active)
    )
    #expect(
      !AuthView.shouldFinishForJSSession(
        isDismissible: true,
        session: AuthView.JSSessionSnapshot(id: nil, status: .active)
      )
    )
    #expect(
      !AuthView.shouldFinishForJSSession(
        isDismissible: true,
        session: AuthView.JSSessionSnapshot(id: "sess_1", status: nil)
      )
    )
    #expect(
      !AuthView.shouldFinishForJSSession(
        isDismissible: true,
        session: AuthView.JSSessionSnapshot(id: "sess_1", status: .pending)
      )
    )
    #expect(
      !AuthView.shouldFinishForJSSession(
        isDismissible: true,
        session: AuthView.JSSessionSnapshot(id: "sess_1", status: .expired)
      )
    )
    #expect(AuthView.shouldFinishForJSSession(isDismissible: true, session: active))
  }
}
