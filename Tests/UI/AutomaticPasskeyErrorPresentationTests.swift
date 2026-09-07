#if os(iOS) || os(macOS)

import ClerkJSCore
@testable import ClerkKitUI
import Testing

@MainActor
struct AutomaticPasskeyErrorPresentationTests {
  @Test(arguments: [
    "passkey_already_exists",
    "passkey_invalid_rpID_or_domain",
    "passkey_not_supported",
    "passkey_operation_aborted",
    "passkey_pa_not_supported",
    "passkey_registration_failed",
    "passkey_retrieval_failed",
  ])
  func ceremonyFailuresAreNotPresented(_ code: String) {
    let error = ClerkJSCoreError.javascript("\(code): ceremony failed")

    #expect(AuthStartView.isAutomaticPasskeyCeremonyFailure(error))
    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(error))
  }

  @Test
  func userCancelIsNotPresented() {
    let error = ClerkJSCoreError.javascript("passkey_retrieval_cancelled: The user cancelled.")

    #expect(error.isUserCancelledError)
    #expect(!AuthStartView.shouldPresentAutomaticPasskeyError(error))
  }

  @Test
  func serverRejectionAfterCeremonyIsPresented() {
    let error = ClerkJSCoreError.javascript("form_param_value_invalid: Invalid passkey.")

    #expect(!AuthStartView.isAutomaticPasskeyCeremonyFailure(error))
    #expect(AuthStartView.shouldPresentAutomaticPasskeyError(error))
  }
}

#endif
