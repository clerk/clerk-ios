#if canImport(AuthenticationServices) && !os(watchOS)

import AuthenticationServices
@testable import ClerkKit
import Foundation
import Testing

struct SignInWithAppleHelperTests {
  private static let unknownErrors: [any Error] = [
    ASAuthorizationError(.unknown),
    NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.Code.unknown.rawValue),
  ]

  @Test(arguments: unknownErrors)
  func unknownAuthorizationErrorKeepsCodeAndExplainsHowToRecover(error: any Error) {
    let result = SignInWithAppleHelper.localizedAuthorizationError(error) as NSError

    #expect(result.domain == ASAuthorizationError.errorDomain)
    #expect(result.code == ASAuthorizationError.Code.unknown.rawValue)
    #expect(result.localizedDescription == "Unable to sign in with Apple. Make sure you're signed in to your Apple Account in Settings, then try again.")
  }

  @Test
  func canceledAuthorizationErrorIsReturnedUnchanged() {
    let error = ASAuthorizationError(.canceled)

    let result = SignInWithAppleHelper.localizedAuthorizationError(error) as NSError

    #expect(result == error as NSError)
    #expect(result.userInfo[NSLocalizedDescriptionKey] == nil)
  }

  @Test
  func unrelatedErrorIsReturnedUnchanged() {
    let error = URLError(.notConnectedToInternet)

    let result = SignInWithAppleHelper.localizedAuthorizationError(error) as NSError

    #expect(result == error as NSError)
    #expect(result.userInfo[NSLocalizedDescriptionKey] == nil)
  }
}

#endif
