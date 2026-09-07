#if os(iOS) || os(macOS)

import AuthenticationServices
@testable import ClerkKitUI
import Foundation
import Testing

struct UserCancellationErrorTests {
  @Test(arguments: AuthorizationErrorInput.all)
  func canceledAuthorizationErrorIsUserCancellation(
    input: AuthorizationErrorInput
  ) {
    let error = authorizationError(
      code: ASAuthorizationError.Code.canceled.rawValue,
      input: input
    )

    #expect(error.isUserCancelledError)
  }

  @Test(
    arguments: AuthorizationErrorScenario.nonCancellationErrors,
    AuthorizationErrorInput.all
  )
  func nonCanceledAuthorizationErrorIsNotUserCancellation(
    scenario: AuthorizationErrorScenario,
    input: AuthorizationErrorInput
  ) {
    let error = authorizationError(
      code: scenario.code,
      input: input
    )

    #expect(!error.isUserCancelledError)
  }

  @Test
  func canceledWebAuthenticationSessionIsUserCancellation() {
    let error = ASWebAuthenticationSessionError(.canceledLogin)

    #expect(error.isUserCancelledError)
  }

  @Test
  func taskCancellationIsNotUserCancellation() {
    let error = CancellationError()

    #expect(!error.isUserCancelledError)
    #expect(error.isCancellationError)
  }

  private func authorizationError(
    code: Int,
    input: AuthorizationErrorInput
  ) -> any Error {
    let userInfo: [String: Any] = if input.includesFailureReason {
      [NSLocalizedFailureReasonErrorKey: "Failure reason"]
    } else {
      [:]
    }
    let nsError = NSError(
      domain: ASAuthorizationError.errorDomain,
      code: code,
      userInfo: userInfo
    )

    switch input.representation {
    case .typed:
      return ASAuthorizationError(_nsError: nsError)
    case .nsError:
      return nsError
    }
  }
}

struct AuthorizationErrorInput: CustomTestStringConvertible {
  let representation: AuthorizationErrorRepresentation
  let includesFailureReason: Bool

  var testDescription: String {
    "\(representation), includesFailureReason: \(includesFailureReason)"
  }

  static let all = AuthorizationErrorRepresentation.allCases.flatMap { representation in
    [
      AuthorizationErrorInput(representation: representation, includesFailureReason: false),
      AuthorizationErrorInput(representation: representation, includesFailureReason: true),
    ]
  }
}

enum AuthorizationErrorRepresentation: CaseIterable {
  case typed
  case nsError
}

struct AuthorizationErrorScenario: CustomTestStringConvertible {
  let name: String
  let code: Int

  var testDescription: String {
    "\(name) (\(code))"
  }

  static let nonCancellationErrors = [
    AuthorizationErrorScenario(name: "unknown", code: 1000),
    AuthorizationErrorScenario(name: "invalidResponse", code: 1002),
    AuthorizationErrorScenario(name: "notHandled", code: 1003),
    AuthorizationErrorScenario(name: "failed", code: 1004),
    AuthorizationErrorScenario(name: "notInteractive", code: 1005),
    AuthorizationErrorScenario(name: "matchedExcludedCredential", code: 1006),
    AuthorizationErrorScenario(name: "credentialImport", code: 1007),
    AuthorizationErrorScenario(name: "credentialExport", code: 1008),
    AuthorizationErrorScenario(name: "preferSignInWithApple", code: 1009),
    AuthorizationErrorScenario(name: "deviceNotConfiguredForPasskeyCreation", code: 1010),
    AuthorizationErrorScenario(name: "futureError", code: 1099),
  ]
}

#endif
