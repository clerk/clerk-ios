@testable import ClerkKit
import ClerkSnapshots
import Foundation

extension RecordingEngineClient {
  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    lastJSMethod = invocation.method
    if case .userResource(let collection, let id) = invocation.receiver {
      let data = try await callUserChild(
        pick: collection.rawValue,
        id: id.rawValue,
        method: invocation.method,
        args: Data()
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    }
    if case .listed(let kind, let id) = invocation.receiver {
      let data = try await callListedChild(
        organizationId: nil,
        locate: listedLocateName(kind),
        locateArgs: Data(),
        findId: id.rawValue,
        method: invocation.method,
        args: Data()
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    }
    if case .organization(let id) = invocation.receiver {
      let data = try await callOrganizationMethod(
        id: id.rawValue,
        method: invocation.method,
        args: (invocation.arguments.first ?? .object([:])).data()
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    }
    if case .billing = invocation.receiver {
      let data = try await callInstance(
        root: "billing",
        method: invocation.method,
        args: (invocation.arguments.first ?? .object([:])).data()
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    }
    if case .signIn = invocation.receiver {
      try await dispatchSignIn(invocation)
      return .null
    }
    if case .signUp = invocation.receiver {
      try await dispatchSignUp(invocation)
      return .null
    }
    if case .session = invocation.receiver {
      return try await dispatchSession(invocation)
    }
    switch invocation.method {
    case "update":
      let params = try decodeInvocation(UpdateUserParams.self, invocation)
      try await updateUser(
        username: params.username,
        firstName: params.firstName,
        lastName: params.lastName,
        primaryEmailAddressId: params.primaryEmailAddressId,
        primaryPhoneNumberId: params.primaryPhoneNumberId,
        unsafeMetadata: params.unsafeMetadata.map { try json(from: $0) }
      )
      return .null
    case "updateMetadata":
      let params = try decodeInvocation(UpdateUserMetadataParams.self, invocation)
      try await updateUserMetadata(unsafeMetadata: json(from: params.unsafeMetadata))
      return .null
    case "updatePassword":
      let params = try decodeInvocation(UpdateUserPasswordParams.self, invocation)
      try await updatePassword(
        currentPassword: params.currentPassword,
        newPassword: params.newPassword,
        signOutOfOtherSessions: params.signOutOfOtherSessions ?? true
      )
      return .null
    case "createEmailAddress":
      let params = try decodeInvocation(CreateEmailAddressParams.self, invocation)
      try await createEmailAddress(params.email)
      return try encodeKit(ClerkKit.EmailAddress(id: "idn_added", emailAddress: params.email))
    case "createPhoneNumber":
      let params = try decodeInvocation(CreatePhoneNumberParams.self, invocation)
      try await createPhoneNumber(params.phoneNumber)
      return try encodeKit(
        ClerkKit.PhoneNumber(
          id: "idn_phone_added",
          phoneNumber: params.phoneNumber,
          reservedForSecondFactor: false,
          defaultSecondFactor: false
        )
      )
    case "createTOTP":
      return try await JSONDecoder().decode(JSONValue.self, from: createTOTP())
    case "verifyTOTP":
      let params = try decodeInvocation(VerifyTOTPParams.self, invocation)
      return try await JSONDecoder().decode(JSONValue.self, from: verifyTOTP(code: params.code))
    case "delete":
      return try await JSONDecoder().decode(JSONValue.self, from: deleteUser())
    case "reload":
      try await reloadUser()
      return .null
    case "createBackupCode":
      return try await JSONDecoder().decode(JSONValue.self, from: createBackupCodes())
    case "disableTOTP":
      return try await JSONDecoder().decode(JSONValue.self, from: disableTOTP())
    case "createExternalAccount":
      let params = try decodeInvocation(CreateExternalAccountParams.self, invocation)
      let account = try await createExternalAccount(
        strategy: params.strategy ?? "",
        redirectUrl: params.redirectUrl,
        additionalScopes: params.additionalScopes ?? [],
        oidcPrompt: params.oidcPrompt,
        token: params.token
      )
      return try encodeKit(account)
    case "createPasskey":
      return try await encodeKit(createPasskey())
    case "getOrganizationInvitations":
      let params = try decodeInvocation(GetUserOrganizationInvitationsParams.self, invocation)
      let data = try await getOrganizationInvitations(
        page: params.initialPage ?? 1,
        pageSize: params.pageSize ?? 20,
        status: invitationStatusStrings(params.status)
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    case "getOrganizationMemberships":
      let params = try decodeInvocation(GetUserOrganizationMembershipParams.self, invocation)
      let data = try await getOrganizationMemberships(
        page: params.initialPage ?? 1,
        pageSize: params.pageSize ?? 20
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    case "getOrganizationSuggestions":
      let params = try decodeInvocation(GetUserOrganizationSuggestionsParams.self, invocation)
      let data = try await getOrganizationSuggestions(
        page: params.initialPage ?? 1,
        pageSize: params.pageSize ?? 20,
        status: statusStrings(params.status)
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    case "getSessions":
      return try await JSONDecoder().decode(JSONValue.self, from: getSessions())
    case "leaveOrganization":
      let organizationId = try stringArgument(invocation)
      return try await JSONDecoder().decode(JSONValue.self, from: leaveOrganization(organizationId: organizationId))
    case "getOrganizationCreationDefaults":
      return try await JSONDecoder().decode(JSONValue.self, from: getOrganizationCreationDefaults())
    case "signOut":
      let sessionId: String? = if let options = try? decodeInvocation(SignOutOptions.self, invocation) {
        options.sessionId
      } else {
        nil
      }
      try await signOut(sessionId: sessionId)
      return .null
    case "setActive":
      let params = try decodeInvocation(SetActiveParams.self, invocation)
      let sessionId: String = if case .string(let value) = params.session {
        value
      } else {
        ""
      }
      let organizationId: String? = if case .string(let value) = params.organization {
        value
      } else {
        nil
      }
      try await setActive(sessionId: sessionId, organizationId: organizationId)
      return .null
    case "revoke":
      listedLocate = "getSessions"
      listedMethod = "revoke"
      return try encodeKit(ClerkKit.Session.mock)
    case "getToken":
      return .string("jwt_engine")
    case "getPaymentMethods":
      let data = try await callInstance(
        root: "user",
        method: invocation.method,
        args: (invocation.arguments.first ?? .object([:])).data()
      )
      return try JSONDecoder().decode(JSONValue.self, from: data)
    case "createOrganization":
      let params = try decodeInvocation(CreateOrganizationParams.self, invocation)
      return try await encodeKit(createOrganization(name: params.name, slug: params.slug))
    case "getOrganization":
      return try await encodeKit(getOrganization(id: stringArgument(invocation)))
    default:
      throw ClerkClientError(message: "Unhandled JS invocation \(invocation.method)")
    }
  }

  private func dispatchSignIn(_ invocation: ClerkJSInvocation) async throws {
    switch invocation.method {
    case "create":
      let params = try decodeInvocation(SignInCreateParams.self, invocation)
      if params.transfer == true {
        try await transferToSignIn()
      } else if params.strategy == "email_code", let identifier = params.identifier {
        try await signInWithEmailCode(emailAddress: identifier)
      } else if params.strategy == "phone_code", let identifier = params.identifier {
        try await signInWithPhoneCode(phoneNumber: identifier)
      } else if params.strategy == "password", let identifier = params.identifier, let password = params.password {
        try await signInWithPassword(identifier: identifier, password: password)
      } else if params.strategy == "ticket", let ticket = params.ticket {
        try await signInWithTicket(ticket)
      } else if params.strategy == "passkey" {
        try await createPasskeySignIn()
      } else if params.strategy == "enterprise_sso" {
        try await startEnterpriseSSO(
          emailAddress: params.identifier ?? "",
          redirectUrl: params.redirectUrl ?? ""
        )
      } else if let token = params.token, let strategy = params.strategy {
        try await signInWithIdToken(strategy: strategy, token: token)
      } else if let identifier = params.identifier {
        try await signIn(identifier: identifier)
      } else {
        throw ClerkClientError(message: "Unhandled signIn.create")
      }
    case "prepareFirstFactor":
      let params = try decodeInvocation(ClerkSnapshots.PrepareFirstFactorParams.self, invocation)
      switch params.strategy {
      case "email_code":
        try await sendEmailCode(emailAddressId: params.emailAddressId)
      case "phone_code":
        try await sendPhoneCode(phoneNumberId: params.phoneNumberId)
      case "email_link":
        try await sendEmailLink(
          emailAddressId: params.emailAddressId,
          redirectUrl: params.redirectUrl ?? "",
          codeChallenge: params.codeChallenge ?? "",
          codeChallengeMethod: params.codeChallengeMethod ?? ""
        )
      case "reset_password_email_code":
        try await sendResetPasswordEmailCode(emailAddressId: params.emailAddressId)
      case "reset_password_phone_code":
        try await sendResetPasswordPhoneCode(phoneNumberId: params.phoneNumberId)
      case "enterprise_sso":
        break
      default:
        _ = try await callInstance(
          root: "signIn",
          method: invocation.method,
          args: (invocation.arguments.first ?? .object([:])).data()
        )
      }
    case "attemptFirstFactor":
      let args = try decodeInvocation(FirstFactorAttemptArgs.self, invocation)
      if args.token != nil {
        try await authenticateWithIdToken(strategy: args.strategy, token: args.token ?? "")
      } else if args.strategy == "email_code", let code = args.code {
        try await verifyEmailCode(code)
      } else if args.strategy == "phone_code", let code = args.code {
        try await verifyPhoneCode(code)
      } else if args.strategy == "password", let password = args.password {
        try await authenticateWithPassword(password)
      } else if args.strategy == "reset_password_email_code", let code = args.code {
        try await verifyResetPasswordCode(code, isEmail: true)
      } else if args.strategy == "reset_password_phone_code", let code = args.code {
        try await verifyResetPasswordCode(code, isEmail: false)
      } else {
        _ = try await callInstance(
          root: "signIn",
          method: invocation.method,
          args: (invocation.arguments.first ?? .object([:])).data()
        )
      }
    case "prepareSecondFactor":
      let params = try decodeInvocation(PrepareSecondFactorParams.self, invocation)
      switch params.strategy {
      case .phoneCode:
        try await sendMfaPhoneCode(phoneNumberId: params.phoneNumberId)
      case .emailCode:
        try await sendMfaEmailCode(emailAddressId: params.emailAddressId)
      default:
        _ = try await callInstance(
          root: "signIn",
          method: invocation.method,
          args: (invocation.arguments.first ?? .object([:])).data()
        )
      }
    case "attemptSecondFactor":
      if let args = try? decodeInvocation(SecondFactorAttemptArgs.self, invocation), let code = args.code {
        try await verifyMfaCode(code, type: mfaType(args.strategy))
      } else {
        _ = try await callInstance(
          root: "signIn",
          method: invocation.method,
          args: (invocation.arguments.first ?? .object([:])).data()
        )
      }
    case "resetPassword":
      let params = try decodeInvocation(ResetPasswordParams.self, invocation)
      try await resetPassword(
        password: params.password,
        signOutOfOtherSessions: params.signOutOfOtherSessions ?? false
      )
    case "authenticateWithRedirect":
      let args = try decodeInvocation(SignInRedirectArgs.self, invocation)
      try await authenticateWithRedirect(
        strategy: args.strategy,
        redirectUrl: args.redirectUrl,
        identifier: args.identifier
      )
    case "authenticateWithPasskey":
      let params = try? decodeInvocation(AuthenticateWithPasskeyParams.self, invocation)
      try await authenticateWithPasskey(autofill: params?.flow == .autofill)
    default:
      _ = try await callInstance(
        root: "signIn",
        method: invocation.method,
        args: (invocation.arguments.first ?? .object([:])).data()
      )
    }
  }

  private func dispatchSignUp(_ invocation: ClerkJSInvocation) async throws {
    switch invocation.method {
    case "create":
      let params = try decodeInvocation(SignUpCreateParams.self, invocation)
      if params.transfer == true {
        try await transferToSignUp(unsafeMetadata: params.unsafeMetadata.map { try json(from: $0) })
      } else if params.strategy == "ticket", let ticket = params.ticket {
        try await signUpWithTicket(ticket)
      } else if let token = params.token, let strategy = params.strategy {
        try await signUpWithIdToken(
          strategy: strategy,
          token: token,
          firstName: params.firstName,
          lastName: params.lastName
        )
      } else {
        try await signUp(
          emailAddress: params.emailAddress,
          password: params.password,
          firstName: params.firstName,
          lastName: params.lastName,
          username: params.username,
          phoneNumber: params.phoneNumber,
          legalAccepted: params.legalAccepted,
          transfer: params.transfer == true
        )
      }
    case "update":
      let params = try decodeInvocation(SignUpCreateParams.self, invocation)
      try await updateSignUp(
        emailAddress: params.emailAddress,
        password: params.password,
        firstName: params.firstName,
        lastName: params.lastName,
        username: params.username,
        phoneNumber: params.phoneNumber,
        legalAccepted: params.legalAccepted
      )
    case "prepareVerification":
      let args = try decodeInvocation(SignUpPrepareArgs.self, invocation)
      if args.strategy == "email_link" {
        try await sendSignUpEmailLink(
          redirectUrl: args.redirectUrl ?? "",
          codeChallenge: args.codeChallenge ?? "",
          codeChallengeMethod: args.codeChallengeMethod ?? ""
        )
      } else if args.strategy == "phone_code" {
        try await sendSignUpPhoneCode()
      } else {
        try await sendSignUpEmailCode()
      }
    case "attemptVerification":
      let params = try decodeInvocation(AttemptVerificationParams.self, invocation)
      switch params.strategy {
      case .phoneCode:
        try await verifySignUpPhoneCode(params.code ?? "")
      default:
        try await verifySignUpEmailCode(params.code ?? "")
      }
    case "authenticateWithRedirect":
      let args = try decodeInvocation(SignUpRedirectArgs.self, invocation)
      try await authenticateSignUpWithRedirect(
        strategy: args.strategy,
        redirectUrl: args.redirectUrl,
        emailAddress: args.emailAddress
      )
    default:
      _ = try await callInstance(
        root: "signUp",
        method: invocation.method,
        args: (invocation.arguments.first ?? .object([:])).data()
      )
    }
  }

  private func dispatchSession(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    switch invocation.method {
    case "getToken":
      return .string("jwt_engine")
    case "revoke":
      listedLocate = "getSessions"
      listedMethod = "revoke"
      return try encodeKit(ClerkKit.Session.mock)
    case "startVerification":
      let params = try decodeInvocation(SessionVerifyCreateParams.self, invocation)
      return try await encodeKit(startSessionVerification(level: sessionLevelString(params.level)))
    case "prepareFirstFactorVerification":
      let params = try decodeInvocation(SessionVerifyPrepareFirstFactorParams.self, invocation)
      return try await encodeKit(
        prepareSessionFirstFactor(
          strategy: sessionPrepareStrategyString(params.strategy),
          emailAddressId: params.emailAddressId,
          phoneNumberId: params.phoneNumberId,
          enterpriseConnectionId: params.enterpriseConnectionId,
          redirectUrl: params.redirectUrl
        )
      )
    case "attemptFirstFactorVerification":
      let args = try decodeInvocation(SessionAttemptArgs.self, invocation)
      return try await encodeKit(
        attemptSessionFirstFactor(
          strategy: args.strategy,
          code: args.code,
          password: args.password,
          publicKeyCredential: args.publicKeyCredential
        )
      )
    case "prepareSecondFactorVerification":
      let params = try decodeInvocation(PhoneCodeSecondFactorConfig.self, invocation)
      return try await encodeKit(
        prepareSessionSecondFactor(strategy: params.strategy, phoneNumberId: params.phoneNumberId)
      )
    case "attemptSecondFactorVerification":
      let args = try decodeInvocation(SessionAttemptArgs.self, invocation)
      return try await encodeKit(
        attemptSessionSecondFactor(
          strategy: args.strategy,
          code: args.code,
          publicKeyCredential: args.publicKeyCredential
        )
      )
    case "verifyWithPasskey":
      return try await encodeKit(verifySessionWithPasskey())
    default:
      throw ClerkClientError(message: "Unhandled session JS invocation \(invocation.method)")
    }
  }

  private func mfaType(_ strategy: String) -> ClerkKit.SignIn.MfaType {
    switch strategy {
    case "phone_code":
      .phoneCode
    case "email_code":
      .emailCode
    case "totp":
      .totp
    case "backup_code":
      .backupCode
    default:
      .phoneCode
    }
  }

  private func decodeInvocation<T: Decodable>(_ type: T.Type, _ invocation: ClerkJSInvocation) throws -> T {
    try JSONDecoder().decode(type, from: (invocation.arguments.first ?? .null).data())
  }

  private func stringArgument(_ invocation: ClerkJSInvocation) throws -> String {
    guard case .string(let value) = invocation.arguments.first else {
      throw ClerkClientError(message: "Expected a string JS argument")
    }
    return value
  }

  private func json(from value: JSONValue) throws -> ClerkKit.JSON {
    try JSONDecoder().decode(ClerkKit.JSON.self, from: value.data())
  }

  private func encodeKit(_ value: some Encodable) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: JSONEncoder.clerkEncoder.encode(value))
  }

  private func invitationStatusStrings(_ status: GetUserOrganizationInvitationsParamsStatus?) -> [String] {
    switch status {
    case .expired:
      ["expired"]
    case .revoked:
      ["revoked"]
    case .pending:
      ["pending"]
    case .accepted:
      ["accepted"]
    case .unknown(let raw):
      [raw]
    case nil:
      []
    }
  }

  private func listedLocateName(_ kind: ClerkJSReceiver.ListedKind) -> String {
    switch kind {
    case .organizationDomain:
      "getDomain"
    case .organizationInvitation:
      "getInvitations"
    case .organizationMembershipRequest:
      "getMembershipRequests"
    case .organizationSuggestion:
      "getOrganizationSuggestions"
    case .userOrganizationInvitation:
      "getOrganizationInvitations"
    case .sessionWithActivities:
      "getSessions"
    case .organizationMembership:
      "getMemberships"
    case .organizationEnterpriseConnection:
      "getEnterpriseConnections"
    case .billingPaymentMethod:
      "getPaymentMethods"
    }
  }

  private func statusStrings(_ value: JSONValue?) -> [String] {
    guard case .array(let values) = value else {
      if case .string(let status) = value {
        return [status]
      }
      return []
    }
    return values.compactMap { item in
      if case .string(let status) = item {
        return status
      }
      return nil
    }
  }
}

private struct FirstFactorAttemptArgs: Decodable {
  var strategy: String
  var code: String?
  var password: String?
  var token: String?
}

private struct SecondFactorAttemptArgs: Decodable {
  var strategy: String
  var code: String?
}

private struct SessionAttemptArgs: Decodable {
  var strategy: String
  var code: String?
  var password: String?
  var publicKeyCredential: String?
}

private func sessionLevelString(_ level: SessionVerifyCreateParamsLevel) -> String {
  switch level {
  case .firstFactor:
    "first_factor"
  case .secondFactor:
    "second_factor"
  case .multiFactor:
    "multi_factor"
  case .unknown(let value):
    value
  }
}

private func sessionPrepareStrategyString(_ strategy: SessionVerifyPrepareFirstFactorParamsStrategy) -> String {
  switch strategy {
  case .passkey:
    "passkey"
  case .emailCode:
    "email_code"
  case .phoneCode:
    "phone_code"
  case .enterpriseSso:
    "enterprise_sso"
  case .unknown(let value):
    value
  }
}

private struct SignUpPrepareArgs: Decodable {
  var strategy: String?
  var redirectUrl: String?
  var codeChallenge: String?
  var codeChallengeMethod: String?
}

private struct SignInRedirectArgs: Decodable {
  var strategy: String
  var redirectUrl: String
  var identifier: String?
}

private struct SignUpRedirectArgs: Decodable {
  var strategy: String
  var redirectUrl: String
  var emailAddress: String?
}
