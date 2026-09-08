@testable import ClerkKit
import ClerkSnapshots
import Foundation

extension RecordingEngineClient {
  func updateUser(
    username: String?,
    firstName: String?,
    lastName: String?,
    primaryEmailAddressId: String?,
    primaryPhoneNumberId: String?,
    unsafeMetadata: JSON?
  ) async throws {
    updatedUsername = username
    updatedFirstName = firstName
    updatedLastName = lastName
    updatedPrimaryEmailAddressId = primaryEmailAddressId
    updatedPrimaryPhoneNumberId = primaryPhoneNumberId
    updatedUnsafeMetadata = unsafeMetadata
    var user = currentUser
    user.firstName = firstName ?? user.firstName
    user.lastName = lastName ?? user.lastName
    user.username = username ?? user.username
    user.primaryEmailAddressId = primaryEmailAddressId ?? user.primaryEmailAddressId
    user.primaryPhoneNumberId = primaryPhoneNumberId ?? user.primaryPhoneNumberId
    if let unsafeMetadata {
      user.unsafeMetadata = unsafeMetadata.jsonValue
    }
    publish(user)
  }

  func updatePassword(currentPassword: String?, newPassword: String, signOutOfOtherSessions: Bool) async throws {
    updatedPasswordCurrent = currentPassword
    updatedPasswordNew = newPassword
    updatedPasswordSignOutOfOtherSessions = signOutOfOtherSessions
    publish(currentUser)
  }

  func createEmailAddress(_ emailAddress: String) async throws {
    createdEmail = emailAddress
    var user = currentUser
    user.emailAddresses.append(EmailAddress(id: "idn_added", emailAddress: emailAddress))
    publish(user)
  }

  func createPhoneNumber(_ phoneNumber: String) async throws {
    createdPhone = phoneNumber
    var user = currentUser
    user.phoneNumbers.append(
      PhoneNumber(
        id: "idn_phone_added",
        phoneNumber: phoneNumber,
        reservedForSecondFactor: false,
        defaultSecondFactor: false
      )
    )
    publish(user)
  }

  func createTOTP() async throws -> Data {
    Data(#"{"object":"totp","id":"totp_engine","verified":false,"created_at":0,"updated_at":0}"#.utf8)
  }

  func verifyTOTP(code: String) async throws -> Data {
    verifiedTotpCode = code
    return Data(#"{"object":"totp","id":"totp_engine","verified":true,"created_at":0,"updated_at":0}"#.utf8)
  }

  func deleteUser() async throws -> Data {
    deletedUser = true
    return Data(#"{"object":"user","id":"1","deleted":true}"#.utf8)
  }

  func reloadUser() async throws {
    reloadedUser = true
    publish(currentUser)
  }

  func updateUserMetadata(unsafeMetadata: JSON) async throws {
    updatedMetadata = unsafeMetadata
    var user = currentUser
    user.unsafeMetadata = unsafeMetadata.jsonValue
    publish(user)
  }

  func createBackupCodes() async throws -> Data {
    createdBackupCodes = true
    return Data(#"{"object":"backup_code","id":"1","codes":["abcd"],"created_at":0,"updated_at":0}"#.utf8)
  }

  func disableTOTP() async throws -> Data {
    disabledTOTP = true
    return Data(#"{"object":"totp","id":"1","deleted":true}"#.utf8)
  }

  func createExternalAccount(
    strategy: String,
    redirectUrl: String?,
    additionalScopes: [String],
    oidcPrompt: String?,
    token: String?
  ) async throws -> ExternalAccount {
    createdExternalAccountStrategy = strategy
    createdExternalAccountRedirectUrl = redirectUrl
    createdExternalAccountScopes = additionalScopes
    createdExternalAccountPrompt = oidcPrompt
    createdExternalAccountToken = token
    return .mockVerified
  }

  func createPasskey() async throws -> Passkey {
    createdPasskey = true
    return .mock
  }

  func createOrganization(name: String, slug: String?) async throws -> Organization {
    createdOrganizationName = name
    createdOrganizationSlug = slug
    return .mock
  }

  func getOrganization(id: String) async throws -> Organization {
    fetchedOrganizationId = id
    return .mock
  }

  func callOrganizationMethod(id: String, method: String, args: Data) async throws -> Data {
    organizationMethodId = id
    organizationMethodName = method
    organizationMethodArgs = args
    switch method {
    case "update":
      return try JSONEncoder.clerkEncoder.encode(Organization.mock)
    case "destroy":
      return Data(#"{"object":"deleted","id":"1","deleted":true}"#.utf8)
    case "getRoles":
      return try JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [RoleResource.mock], totalCount: 1))
    case "getMemberships":
      return try JSONEncoder.clerkEncoder.encode(
        ClerkPaginatedResponse(data: [OrganizationMembership.mockWithUserData], totalCount: 1)
      )
    case "addMember", "updateMember", "removeMember":
      return try JSONEncoder.clerkEncoder.encode(OrganizationMembership.mockWithUserData)
    case "getInvitations":
      return try JSONEncoder.clerkEncoder.encode(
        ClerkPaginatedResponse(data: [OrganizationInvitation.mock], totalCount: 1)
      )
    case "inviteMember":
      return try JSONEncoder.clerkEncoder.encode(OrganizationInvitation.mock)
    case "inviteMembers":
      return try JSONEncoder.clerkEncoder.encode([OrganizationInvitation.mock])
    case "createDomain", "getDomain":
      return try JSONEncoder.clerkEncoder.encode(OrganizationDomain.mock)
    case "getDomains":
      return try JSONEncoder.clerkEncoder.encode(
        ClerkPaginatedResponse(data: [OrganizationDomain.mock], totalCount: 1)
      )
    case "getMembershipRequests":
      return try JSONEncoder.clerkEncoder.encode(
        ClerkPaginatedResponse(data: [OrganizationMembershipRequest.mock], totalCount: 1)
      )
    case "getPaymentMethods":
      return try JSONEncoder.clerkEncoder.encode(
        ClerkPaginatedResponse(data: [BillingPaymentMethod.mock], totalCount: 1)
      )
    default:
      throw ClerkClientError(message: "Unexpected organization method \(method)")
    }
  }

  var instanceArgsObject: [String: Any] {
    jsonObject(instanceArgs)
  }

  func callUserChild(pick: String, id: String, method: String, args _: Data) async throws -> Data {
    userChildPick = pick
    userChildId = id
    userChildMethod = method
    if method == "destroy" || method == "delete" {
      return Data(#"{"object":"deleted","id":"1","deleted":true}"#.utf8)
    }
    switch pick {
    case "emailAddresses":
      return try JSONEncoder.clerkEncoder.encode(EmailAddress.mock)
    case "phoneNumbers":
      return try JSONEncoder.clerkEncoder.encode(PhoneNumber.mock)
    case "passkeys":
      return try JSONEncoder.clerkEncoder.encode(Passkey.mock)
    case "externalAccounts":
      return try JSONEncoder.clerkEncoder.encode(ExternalAccount.mockVerified)
    default:
      throw ClerkClientError(message: "Unexpected user child \(pick)")
    }
  }

  func listedFixture(kind: ClerkJSReceiver.ListedKind, method: String) throws -> Data {
    if method == "delete" || method == "destroy" {
      return Data(#"{"object":"deleted","id":"1","deleted":true}"#.utf8)
    }
    switch kind {
    case .organizationInvitation:
      return try JSONEncoder.clerkEncoder.encode(OrganizationInvitation.mock)
    case .organizationDomain:
      return try JSONEncoder.clerkEncoder.encode(OrganizationDomain.mock)
    case .userOrganizationInvitation:
      return try JSONEncoder.clerkEncoder.encode(UserOrganizationInvitation.mock)
    case .organizationSuggestion:
      return try JSONEncoder.clerkEncoder.encode(OrganizationSuggestion.mock)
    case .organizationMembershipRequest:
      return try JSONEncoder.clerkEncoder.encode(OrganizationMembershipRequest.mock)
    case .sessionWithActivities:
      return try JSONEncoder.clerkEncoder.encode(Session.mock)
    default:
      throw ClerkClientError(message: "No listed fixture for \(kind)")
    }
  }

  func callInstance(root: String, method: String, args: Data) async throws -> Data {
    instanceRoot = root
    instanceMethod = method
    instanceArgs = args
    allInstanceMethods.append(method)
    if let error = instanceMethodErrors[method] {
      throw error
    }
    if method == "prepareFirstFactor"
      || method == "prepareSecondFactor"
      || method == "attemptFirstFactor"
      || method == "attemptSecondFactor"
    {
      publish(signInOnReload)
      return try JSONEncoder.clerkEncoder.encode(signInOnReload)
    }
    if method == "reload" {
      reloadedNonce = jsonObject(args)["rotatingTokenNonce"] as? String
      if root == "signIn" {
        publish(signInOnReload)
        return try JSONEncoder.clerkEncoder.encode(signInOnReload)
      }
      if root == "signUp" {
        publish(signUpOnReload)
        return try JSONEncoder.clerkEncoder.encode(signUpOnReload)
      }
    }
    if method == "getPaymentMethods" {
      return try JSONEncoder.clerkEncoder.encode(
        ClerkPaginatedResponse(data: [BillingPaymentMethod.mock], totalCount: 1)
      )
    }
    if root == "billing" {
      switch method {
      case "getPlans":
        return try JSONEncoder.clerkEncoder.encode(
          ClerkPaginatedResponse(data: [BillingPlan.mock], totalCount: 1)
        )
      case "getPlan":
        return try JSONEncoder.clerkEncoder.encode(BillingPlan.mock)
      case "getSubscription":
        return try JSONEncoder.clerkEncoder.encode(BillingSubscription.mock)
      case "getStatements":
        return try JSONEncoder.clerkEncoder.encode(
          ClerkPaginatedResponse(data: [BillingStatement.mock], totalCount: 1)
        )
      case "getStatement":
        return try JSONEncoder.clerkEncoder.encode(BillingStatement.mock)
      case "getPaymentAttempts":
        return try JSONEncoder.clerkEncoder.encode(
          ClerkPaginatedResponse(data: [BillingPayment.mock], totalCount: 1)
        )
      case "getPaymentAttempt":
        return try JSONEncoder.clerkEncoder.encode(BillingPayment.mock)
      case "getCreditBalance":
        return try JSONEncoder.clerkEncoder.encode(BillingCreditBalance.mock)
      case "getCreditHistory":
        return try JSONEncoder.clerkEncoder.encode(
          ClerkPaginatedResponse(data: [BillingCreditLedger.mock], totalCount: 1)
        )
      default:
        throw ClerkClientError(message: "Unexpected billing method \(method)")
      }
    }
    throw ClerkClientError(message: "Unexpected instance method \(root).\(method)")
  }

  func getOrganizationInvitations(page: Int, pageSize: Int, status: [String]) async throws -> Data {
    fetchedInvitationPage = page
    fetchedInvitationPageSize = pageSize
    fetchedInvitationStatus = status
    return try JSONEncoder.clerkEncoder.encode(
      ClerkPaginatedResponse(data: [UserOrganizationInvitation.mock], totalCount: 1)
    )
  }

  func getOrganizationMemberships(page: Int, pageSize: Int) async throws -> Data {
    fetchedMembershipPage = page
    fetchedMembershipPageSize = pageSize
    return try JSONEncoder.clerkEncoder.encode(
      ClerkPaginatedResponse(data: [OrganizationMembership.mockWithUserData], totalCount: 1)
    )
  }

  func getOrganizationSuggestions(page: Int, pageSize: Int, status: [String]) async throws -> Data {
    fetchedSuggestionPage = page
    fetchedSuggestionPageSize = pageSize
    fetchedSuggestionStatus = status
    return try JSONEncoder.clerkEncoder.encode(
      ClerkPaginatedResponse(data: [OrganizationSuggestion.mock], totalCount: 1)
    )
  }

  func getSessions() async throws -> Data {
    fetchedSessions = true
    return try JSONEncoder.clerkEncoder.encode([Session.mock])
  }

  func leaveOrganization(organizationId: String) async throws -> Data {
    leftOrganizationId = organizationId
    return Data(#"{"object":"organization_membership","id":"1","deleted":true}"#.utf8)
  }

  func getOrganizationCreationDefaults() async throws -> Data {
    fetchedCreationDefaults = true
    return Data(#"{"form":{"name":"Acme","slug":"acme"}}"#.utf8)
  }
}
