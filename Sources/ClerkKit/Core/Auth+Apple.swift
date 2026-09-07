//
//  Auth+Apple.swift
//  Clerk
//

#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)

import AuthenticationServices
import ClerkSnapshots

extension Auth {
  static func normalizedAppleScopes(
    _ requestedScopes: [ASAuthorization.Scope],
    environment: Clerk.Environment?
  ) -> [ASAuthorization.Scope] {
    guard requestedScopes.contains(.fullName) else {
      return requestedScopes
    }

    let attributes = environment?.userSettings.attributes
    let firstNameEnabled = attributes?.firstName.enabled ?? true
    let lastNameEnabled = attributes?.lastName.enabled ?? true

    return firstNameEnabled || lastNameEnabled
      ? requestedScopes
      : requestedScopes.filter { $0 != .fullName }
  }

  static func appleCredential(
    _ requestedScopes: [ASAuthorization.Scope],
    environment: Clerk.Environment?
  ) async throws -> ASAuthorizationAppleIDCredential {
    let requestedScopes = normalizedAppleScopes(
      requestedScopes,
      environment: environment
    )
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard !credential.tokenString.isEmpty else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.", localizationBundle: .module)
    }

    return credential
  }

  func completeAppleSignIn(
    idToken: String,
    firstName: String?,
    lastName: String?,
    transferable: Bool,
    unsafeMetadata: JSON?
  ) async throws -> TransferFlowResult {
    let result = try await Clerk.js(
      .clerk,
      JSRawCall("completeNativeAppleSignIn", JSONValue(encoding: AppleSignInArgs(
        idToken: idToken, firstName: firstName, lastName: lastName, transferable: transferable, unsafeMetadata: unsafeMetadata?.jsonValue
      ))), as: NativeAuthResult.self
    )
    return try result.transferResult()
  }
}

private struct AppleSignInArgs: Encodable {
  var idToken: String
  var firstName: String?
  var lastName: String?
  var transferable: Bool
  var unsafeMetadata: JSONValue?
}

#endif
