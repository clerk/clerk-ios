//
//  SignUp.swift
//

import AuthenticationServices
import ClerkSnapshots
import Foundation

extension SignUp {
  @discardableResult @MainActor
  func handleRedirectCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
    try await Clerk.completeNativeRedirectCallback(flow: "signUp", expectedId: id, callbackUrl: url)
  }
}
