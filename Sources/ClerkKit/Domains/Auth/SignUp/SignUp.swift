//
//  SignUp.swift
//

import AuthenticationServices
import ClerkSnapshots
import Foundation

extension SignUp {
  var needsTransferToSignIn: Bool {
    verificationByAttribute["external_account"]??.status == .transferable
  }

  @discardableResult @MainActor
  func handleRedirectCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignUp = try await reload(rotatingTokenNonce: nonce)
      if let error = updatedSignUp.verificationByAttribute["external_account"]??.kitError {
        throw error
      }
      return .signUp(updatedSignUp)
    } else {
      let signUp = try await reload()
      let result = try await signUp.handleTransferFlow()
      switch result {
      case .signIn(let signIn):
        if let error = signIn.firstFactorVerification?.kitError {
          throw error
        }
      case .signUp(let signUp):
        if let error = signUp.verificationByAttribute["external_account"]??.kitError {
          throw error
        }
      }
      return result
    }
  }
}
