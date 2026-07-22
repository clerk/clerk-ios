//
//  Auth+Apple.swift
//  Clerk
//

#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)

import AuthenticationServices

extension Auth {
  private static let appleSignUpRestrictionErrorCodes: Set<String> = [
    "sign_up_mode_restricted",
    "sign_up_restricted_waitlist",
  ]

  static func normalizedAppleScopes(
    _ requestedScopes: [ASAuthorization.Scope],
    environment: Clerk.Environment?
  ) -> [ASAuthorization.Scope] {
    guard requestedScopes.contains(.fullName) else {
      return requestedScopes
    }

    let attributes = environment?.userSettings.attributes
    let firstNameEnabled = attributes?["first_name"]?.enabled ?? true
    let lastNameEnabled = attributes?["last_name"]?.enabled ?? true

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
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.")
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
    guard transferable else {
      return try await signInWithIdToken(
        idToken,
        provider: .apple,
        transferable: false,
        unsafeMetadata: unsafeMetadata
      )
    }

    let result: TransferFlowResult
    do {
      result = try await signUpWithIdToken(
        idToken,
        provider: .apple,
        firstName: firstName,
        lastName: lastName,
        unsafeMetadata: unsafeMetadata
      )
    } catch let signUpError as ClerkAPIError
      where Self.appleSignUpRestrictionErrorCodes.contains(signUpError.code)
    {
      let signIn = try await createSignInWithIdToken(idToken, provider: .apple)

      guard !signIn.needsTransferToSignUp else {
        throw signUpError
      }

      if let error = signIn.firstFactorVerification?.error {
        throw error
      }

      return .signIn(signIn)
    }

    if case .signIn(let signIn) = result,
       let error = signIn.firstFactorVerification?.error
    {
      throw error
    }

    return result
  }
}

#endif
