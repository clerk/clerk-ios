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
  static func signIn(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> ASAuthorizationAppleIDCredential {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)
    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the apple identity token.")
    }
    try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
    return credential
  }
  
}

#endif
