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
    default:
      throw ClerkClientError(message: "Unhandled JS invocation \(invocation.method)")
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
