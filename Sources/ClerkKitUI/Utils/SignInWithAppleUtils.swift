//
//  SignInWithAppleUtils.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

#if os(iOS)

import AuthenticationServices
import Foundation

enum SignInWithAppleUtils {

    @discardableResult @MainActor
    static func signIn() async throws -> TransferFlowResult {
        let credential = try await SignInWithAppleHelper.getAppleIdCredential()
        let idToken = credential.tokenString

        if Clerk.shared.environment.signUpIsPublic {
            let firstName = credential.fullName?.givenName.nilIfEmpty
            let lastName = credential.fullName?.familyName.nilIfEmpty
            return try await SignUp.authenticateWithIdToken(provider: .apple, idToken: idToken, firstName: firstName, lastName: lastName)
        } else {
            return try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
        }
    }

}

extension ASAuthorizationAppleIDCredential {

  var tokenString: String {
    identityToken.flatMap({ String(data: $0, encoding: .utf8) }) ?? ""
  }

}

#endif
