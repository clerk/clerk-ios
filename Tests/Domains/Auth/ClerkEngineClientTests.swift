@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkEngineClientTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func signInWithEmailCodeUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)

    let signIn = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: "user@example.com")

    #expect(engine.signedInEmail == "user@example.com")
    #expect(signIn.id == "sia_engine")
    #expect(kitCalls.createCount == 0)
  }

  @Test
  func sendAndVerifyEmailCodeUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)

    _ = try await Clerk.shared.auth.signInWithEmailCode(emailAddress: "user@example.com")
    let current = try #require(Clerk.shared.auth.currentSignIn)
    let prepared = try await current.sendEmailCode(emailAddressId: "idn_email")
    #expect(engine.sentEmailAddressId == "idn_email")
    #expect(prepared.firstFactorVerification?.factorStrategy == .emailCode)

    let verified = try await prepared.verifyCode("424242")
    #expect(engine.verifiedCode == "424242")
    #expect(verified.status == .complete)
    #expect(verified.createdSessionId == "sess_engine")
    #expect(kitCalls.prepareCount == 0)
    #expect(kitCalls.attemptCount == 0)
  }

  @Test
  func passwordPhoneSetActiveAndGetTokenUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSessionService(kitCalls)

    let password = try await Clerk.shared.auth.signInWithPassword(
      identifier: "user@example.com",
      password: "hunter2"
    )
    #expect(engine.passwordIdentifier == "user@example.com")
    #expect(engine.password == "hunter2")
    #expect(password.status == .complete)

    _ = try await Clerk.shared.auth.signInWithPhoneCode(phoneNumber: "+15555550100")
    let phoneSignIn = try #require(Clerk.shared.auth.currentSignIn)
    _ = try await phoneSignIn.sendPhoneCode(phoneNumberId: "idn_phone")
    let verifiedPhone = try await phoneSignIn.verifyCode("424242")
    #expect(engine.signedInPhone == "+15555550100")
    #expect(engine.sentPhoneNumberId == "idn_phone")
    #expect(engine.verifiedPhoneCode == "424242")
    #expect(verifiedPhone.status == .complete)

    try await Clerk.shared.auth.setActive(sessionId: "sess_engine", organizationId: "org_1")
    #expect(engine.activeSessionId == "sess_engine")
    #expect(engine.activeOrganizationId == "org_1")

    let token = try await Clerk.shared.auth.getToken()
    #expect(token == "jwt_engine")

    try await Clerk.shared.auth.signOut()
    #expect(engine.signedOut)
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.setActiveCount == 0)
    #expect(kitCalls.signOutCount == 0)
  }

  @Test
  func signUpEmailCodeUsesEngine() async throws {
    let engine = RecordingEngineClient()
    Clerk.engineClient = engine

    let created = try await Clerk.shared.auth.signUp(emailAddress: "user@example.com")
    #expect(engine.signedUpEmail == "user@example.com")
    #expect(created.emailAddress == "user@example.com")

    _ = try await created.sendEmailCode()
    #expect(engine.sentSignUpEmailCode)

    let verified = try await created.verifyEmailCode("424242")
    #expect(engine.verifiedSignUpEmailCode == "424242")
    #expect(verified.status == .complete)
    #expect(verified.createdSessionId == "sess_engine")
  }

  @Test
  func oauthPasskeyMfaResetAndSignUpUpdateUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    let oauth = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    #expect(engine.redirectStrategy == "oauth_google")
    if case .signIn(let signIn) = oauth {
      #expect(signIn.id == "sia_engine")
    } else {
      Issue.record("Expected a sign-in transfer result")
    }

    engine.publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: "user@example.com")
    )
    let current = try #require(Clerk.shared.auth.currentSignIn)
    _ = try await current.sendResetPasswordEmailCode(emailAddressId: "idn_email")
    _ = try await current.sendResetPasswordPhoneCode(phoneNumberId: "idn_phone")
    engine.publish(
      SignIn(
        id: "sia_engine",
        status: .needsNewPassword,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .verified, strategy: .resetPasswordEmailCode)
      )
    )
    let resetSignIn = try #require(Clerk.shared.auth.currentSignIn)
    let verifiedReset = try await resetSignIn.verifyCode("424242")
    #expect(engine.resetEmailAddressId == "idn_email")
    #expect(engine.resetPhoneNumberId == "idn_phone")
    #expect(engine.verifiedResetCode == "424242")
    #expect(verifiedReset.status == .needsNewPassword)

    let reset = try await current.resetPassword(newPassword: "new-pass", signOutOfOtherSessions: true)
    #expect(engine.resetPassword == "new-pass")
    #expect(engine.resetSignOutOfOtherSessions == true)
    #expect(reset.status == .complete)

    engine.publish(
      SignIn(id: "sia_engine", status: .needsSecondFactor, identifier: "user@example.com")
    )
    let mfaSignIn = try #require(Clerk.shared.auth.currentSignIn)
    _ = try await mfaSignIn.sendMfaEmailCode(emailAddressId: "idn_mfa_email")
    _ = try await mfaSignIn.sendMfaPhoneCode(phoneNumberId: "idn_mfa_phone")
    let mfa = try await mfaSignIn.verifyMfaCode("424242", type: .totp)
    #expect(engine.sentMfaEmailAddressId == "idn_mfa_email")
    #expect(engine.sentMfaPhoneNumberId == "idn_mfa_phone")
    #expect(engine.verifiedMfaCode == "424242")
    #expect(engine.verifiedMfaType == .totp)
    #expect(mfa.status == .complete)

    let passkey = try await Clerk.shared.auth.signInWithPasskey()
    #expect(engine.authenticatedPasskey)
    #expect(passkey.status == .complete)

    engine.publish(SignUp.mock)
    let signUp = try #require(Clerk.shared.auth.currentSignUp)
    let updated = try await signUp.update(firstName: "Ada", lastName: "Lovelace")
    #expect(engine.updatedSignUpFirstName == "Ada")
    #expect(engine.updatedSignUpLastName == "Lovelace")
    #expect(updated.firstName == "Ada")
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.prepareCount == 0)
    #expect(kitCalls.attemptCount == 0)
    #expect(kitCalls.prepareSecondCount == 0)
    #expect(kitCalls.attemptSecondCount == 0)
    #expect(kitCalls.resetPasswordCount == 0)
    #expect(kitCalls.signUpUpdateCount == 0)
  }

  @Test
  func ticketAndIdTokenUseEngine() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    let ticket = try await Clerk.shared.auth.signInWithTicket("tkt_engine")
    #expect(engine.signedInTicket == "tkt_engine")
    #expect(ticket.status == .complete)

    let idToken = try await Clerk.shared.auth.signInWithIdToken("apple_token", provider: .apple)
    #expect(engine.signedInIdToken == "apple_token")
    #expect(engine.signedInIdTokenStrategy == "oauth_token_apple")
    if case .signIn(let signIn) = idToken {
      #expect(signIn.status == .complete)
    } else {
      Issue.record("Expected a sign-in transfer result")
    }

    let signUp = try await Clerk.shared.auth.signUpWithTicket("tkt_signup")
    #expect(engine.signedUpTicket == "tkt_signup")
    #expect(signUp.id == SignUp.mock.id)
    #expect(kitCalls.createCount == 0)
  }

  @Test
  func refreshSkipsKitFAPIWhenEngineIsRegistered() async throws {
    let engine = RecordingEngineClient()
    Clerk.engineClient = engine
    Clerk.shared.environment = .mock

    let environment = try await Clerk.shared.refreshEnvironment()
    let client = try await Clerk.shared.refreshClient()

    #expect(environment.displayConfig.applicationName == Clerk.Environment.mock.displayConfig.applicationName)
    #expect(client == Clerk.shared.client)
    #expect(engine.lastJSMethod == "refreshClient")
  }

  @Test
  func userMutationsUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingUserService(kitCalls)
    engine.publish(User.mock)
    let user = try #require(Clerk.shared.user)

    let updated = try await user.update(.init(firstName: "Ada", lastName: "Lovelace"))
    #expect(engine.updatedUsername == nil)
    #expect(engine.updatedFirstName == "Ada")
    #expect(engine.updatedLastName == "Lovelace")
    #expect(updated.firstName == "Ada")
    #expect(updated.lastName == "Lovelace")

    _ = try await user.updatePassword(
      .init(currentPassword: "old-pass", newPassword: "new-pass", signOutOfOtherSessions: true)
    )
    #expect(engine.updatedPasswordCurrent == "old-pass")
    #expect(engine.updatedPasswordNew == "new-pass")
    #expect(engine.updatedPasswordSignOutOfOtherSessions == true)

    let email = try await user.createEmailAddress("added@example.com")
    #expect(engine.createdEmail == "added@example.com")
    #expect(email.emailAddress == "added@example.com")

    let phone = try await user.createPhoneNumber("+15555550999")
    #expect(engine.createdPhone == "+15555550999")
    #expect(phone.phoneNumber == "+15555550999")

    let totp = try await user.createTOTP()
    #expect(totp.id == "totp_engine")
    #expect(totp.verified == false)

    let verified = try await user.verifyTOTP(code: "424242")
    #expect(engine.verifiedTotpCode == "424242")
    #expect(verified.id == "totp_engine")

    let deleted = try await user.delete()
    #expect(engine.deletedUser)
    #expect(deleted.deleted == true)

    _ = try await user.reload()
    #expect(engine.reloadedUser)

    _ = try await user.updateMetadata(unsafeMetadata: ["plan": "pro"])
    #expect(engine.updatedMetadata == ["plan": "pro"])

    let backupCodes = try await user.createBackupCodes()
    #expect(engine.createdBackupCodes)
    #expect(backupCodes.codes == ["abcd"])

    let disabled = try await user.disableTOTP()
    #expect(engine.disabledTOTP)
    #expect(disabled.deleted == true)

    let oauth = try await user.createExternalAccount(
      provider: .google,
      redirectUrl: "myapp://callback",
      additionalScopes: ["email"],
      oidcPrompts: [.consent]
    )
    #expect(engine.createdExternalAccountStrategy == OAuthProvider.google.strategy)
    #expect(engine.createdExternalAccountRedirectUrl == "myapp://callback")
    #expect(engine.createdExternalAccountScopes == ["email"])
    #expect(engine.createdExternalAccountPrompt == OIDCPrompt.consent.value)
    #expect(oauth.id == ExternalAccount.mockVerified.id)

    let apple = try await user.createExternalAccount(provider: .apple, idToken: "id-token")
    #expect(engine.createdExternalAccountStrategy == IDTokenProvider.apple.strategy)
    #expect(engine.createdExternalAccountToken == "id-token")
    #expect(apple.id == ExternalAccount.mockVerified.id)

    #if canImport(AuthenticationServices) && !os(watchOS)
    let passkey = try await user.createPasskey()
    #expect(engine.createdPasskey)
    #expect(passkey.id == Passkey.mock.id)
    #endif

    let createdOrg = try await Clerk.shared.organizations.create(name: "Acme", slug: "acme")
    #expect(engine.createdOrganizationName == "Acme")
    #expect(engine.createdOrganizationSlug == "acme")
    #expect(createdOrg.id == Organization.mock.id)

    let fetchedOrg = try await Clerk.shared.organizations.get(id: "org_123")
    #expect(engine.fetchedOrganizationId == "org_123")
    #expect(fetchedOrg.id == Organization.mock.id)

    let invitations = try await user.getOrganizationInvitations(
      page: 2,
      pageSize: 10,
      status: ["pending", "accepted"]
    )
    #expect(engine.fetchedInvitationPage == 2)
    #expect(engine.fetchedInvitationPageSize == 10)
    #expect(engine.fetchedInvitationStatus == ["pending"])
    #expect(invitations.data.first?.id == UserOrganizationInvitation.mock.id)

    let memberships = try await user.getOrganizationMemberships(page: 3, pageSize: 10)
    #expect(engine.fetchedMembershipPage == 3)
    #expect(engine.fetchedMembershipPageSize == 10)
    #expect(memberships.data.first?.id == OrganizationMembership.mockWithUserData.id)

    let suggestions = try await user.getOrganizationSuggestions(page: 2, pageSize: 10, status: ["pending"])
    #expect(engine.fetchedSuggestionPage == 2)
    #expect(engine.fetchedSuggestionStatus == ["pending"])
    #expect(suggestions.data.first?.id == OrganizationSuggestion.mock.id)

    let sessions = try await user.getSessions()
    #expect(engine.fetchedSessions)
    #expect(sessions.first?.id == Session.mock.id)
    #expect(Clerk.shared.sessionsByUserId[user.id]?.first?.id == Session.mock.id)

    let left = try await user.leaveOrganization(organizationId: "org_123")
    #expect(engine.leftOrganizationId == "org_123")
    #expect(left.deleted == true)

    let defaults = try await user.getOrganizationCreationDefaults()
    #expect(engine.fetchedCreationDefaults)
    #expect(defaults.form?.name == "Acme")

    #expect(kitCalls.userServiceCount == 0)
  }

  @Test
  func organizationMethodsUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingOrganizationService(kitCalls)
    let organization = Organization.mock

    let updated = try await organization.update(name: "Acme", slug: "acme")
    #expect(engine.organizationMethodId == organization.id)
    #expect(engine.organizationMethodName == "update")
    #expect(jsonObject(engine.organizationMethodArgs)["name"] as? String == "Acme")
    #expect(jsonObject(engine.organizationMethodArgs)["slug"] as? String == "acme")
    #expect(updated.id == Organization.mock.id)

    let deleted = try await organization.destroy()
    #expect(engine.organizationMethodName == "destroy")
    #expect(deleted.deleted == true)

    let roles = try await organization.getRoles(page: 2, pageSize: 10)
    #expect(engine.organizationMethodName == "getRoles")
    #expect(jsonObject(engine.organizationMethodArgs)["initialPage"] as? Int == 2)
    #expect(roles.data.first?.id == RoleResource.mock.id)

    let memberships = try await organization.getMemberships(query: "ada", role: ["org:admin"], page: 3, pageSize: 10)
    #expect(engine.organizationMethodName == "getMemberships")
    #expect(jsonObject(engine.organizationMethodArgs)["initialPage"] as? Int == 3)
    #expect(jsonObject(engine.organizationMethodArgs)["query"] as? String == "ada")
    #expect(memberships.data.first?.id == OrganizationMembership.mockWithUserData.id)

    _ = try await organization.getMemberships(offset: 20, pageSize: 10)
    #expect(jsonObject(engine.organizationMethodArgs)["initialPage"] as? Int == 3)

    let added = try await organization.addMember(userId: "user_123", role: "org:member")
    #expect(engine.organizationMethodName == "addMember")
    #expect(jsonObject(engine.organizationMethodArgs)["userId"] as? String == "user_123")
    #expect(added.id == OrganizationMembership.mockWithUserData.id)

    _ = try await organization.updateMember(userId: "user_123", role: "org:admin")
    #expect(engine.organizationMethodName == "updateMember")

    _ = try await organization.removeMember(userId: "user_123")
    #expect(engine.organizationMethodName == "removeMember")

    let invitations = try await organization.getInvitations(page: 2, pageSize: 10, status: ["pending", "accepted"])
    #expect(engine.organizationMethodName == "getInvitations")
    #expect(jsonObject(engine.organizationMethodArgs)["status"] as? [String] == ["pending", "accepted"])
    #expect(invitations.data.first?.id == OrganizationInvitation.mock.id)

    let invited = try await organization.inviteMember(emailAddress: "ada@example.com", role: "org:member")
    #expect(engine.organizationMethodName == "inviteMember")
    #expect(invited.id == OrganizationInvitation.mock.id)

    let bulk = try await organization.inviteMembers(emailAddresses: ["a@example.com"], role: "org:member")
    #expect(engine.organizationMethodName == "inviteMembers")
    #expect(bulk.first?.id == OrganizationInvitation.mock.id)

    let domain = try await organization.createDomain(domainName: "example.com")
    #expect(engine.organizationMethodName == "createDomain")
    #expect(domain.id == OrganizationDomain.mock.id)

    let domains = try await organization.getDomains(page: 2, pageSize: 10, enrollmentMode: .automaticInvitation)
    #expect(engine.organizationMethodName == "getDomains")
    #expect(jsonObject(engine.organizationMethodArgs)["enrollmentMode"] as? String == "automatic_invitation")
    #expect(domains.data.first?.id == OrganizationDomain.mock.id)

    let fetchedDomain = try await organization.getDomain(domainId: "orgdmn_1")
    #expect(engine.organizationMethodName == "getDomain")
    #expect(jsonObject(engine.organizationMethodArgs)["domainId"] as? String == "orgdmn_1")
    #expect(fetchedDomain.id == OrganizationDomain.mock.id)

    let requests = try await organization.getMembershipRequests(page: 2, pageSize: 10, status: "pending")
    #expect(engine.organizationMethodName == "getMembershipRequests")
    #expect(jsonObject(engine.organizationMethodArgs)["status"] as? String == "pending")
    #expect(requests.data.first?.id == OrganizationMembershipRequest.mock.id)

    #expect(kitCalls.organizationServiceCount == 0)
  }

  @Test
  func nestedOrganizationResourcesUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingOrganizationService(kitCalls)

    let membership = OrganizationMembership.mockWithUserData
    _ = try await membership.update(role: "org:admin")
    #expect(engine.organizationMethodName == "updateMember")
    #expect(jsonObject(engine.organizationMethodArgs)["role"] as? String == "org:admin")

    _ = try await membership.destroy()
    #expect(engine.organizationMethodName == "removeMember")

    let invitation = OrganizationInvitation.mock
    let revoked = try await invitation.revoke()
    #expect(engine.listedLocate == "getInvitations")
    #expect(engine.listedMethod == "revoke")
    #expect(revoked.id == OrganizationInvitation.mock.id)

    let domain = OrganizationDomain.mock
    let deleted = try await domain.delete()
    #expect(engine.listedLocate == "getDomain")
    #expect(engine.listedMethod == "delete")
    #expect(deleted.deleted == true)

    _ = try await domain.prepareAffiliationVerification(affiliationEmailAddress: "ada@example.com")
    #expect(engine.listedMethod == "prepareAffiliationVerification")

    _ = try await domain.attemptAffiliationVerification(code: "424242")
    #expect(engine.listedMethod == "attemptAffiliationVerification")

    _ = try await domain.updateEnrollmentMode(.automaticInvitation, deletePending: true)
    #expect(engine.listedMethod == "updateEnrollmentMode")

    let userInvite = UserOrganizationInvitation.mock
    _ = try await userInvite.accept()
    #expect(engine.listedLocate == "getOrganizationInvitations")
    #expect(engine.listedMethod == "accept")

    let suggestion = OrganizationSuggestion.mock
    _ = try await suggestion.accept()
    #expect(engine.listedLocate == "getOrganizationSuggestions")
    #expect(engine.listedMethod == "accept")

    let request = OrganizationMembershipRequest.mock
    _ = try await request.accept()
    #expect(engine.listedLocate == "getMembershipRequests")
    #expect(engine.listedMethod == "accept")
    _ = try await request.reject()
    #expect(engine.listedMethod == "reject")

    #expect(kitCalls.organizationServiceCount == 0)
  }

  @Test
  func userIdentifierResourcesUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingIdentifierServices(kitCalls)

    let email = EmailAddress.mock
    _ = try await email.sendCode()
    #expect(engine.userChildPick == "emailAddresses")
    #expect(engine.userChildId == email.id)
    #expect(engine.userChildMethod == "prepareVerification")

    _ = try await email.verifyCode("424242")
    #expect(engine.userChildMethod == "attemptVerification")

    let deletedEmail = try await email.destroy()
    #expect(engine.userChildMethod == "destroy")
    #expect(deletedEmail.deleted == true)

    let phone = PhoneNumber.mock
    _ = try await phone.sendCode()
    #expect(engine.userChildPick == "phoneNumbers")
    #expect(engine.userChildMethod == "prepareVerification")
    _ = try await phone.verifyCode("424242")
    #expect(engine.userChildMethod == "attemptVerification")
    _ = try await phone.makeDefaultSecondFactor()
    #expect(engine.userChildMethod == "makeDefaultSecondFactor")
    _ = try await phone.setReservedForSecondFactor(reserved: true)
    #expect(engine.userChildMethod == "setReservedForSecondFactor")
    let deletedPhone = try await phone.delete()
    #expect(engine.userChildMethod == "destroy")
    #expect(deletedPhone.deleted == true)

    let passkey = Passkey.mock
    _ = try await passkey.update(name: "Laptop")
    #expect(engine.userChildPick == "passkeys")
    #expect(engine.userChildMethod == "update")
    _ = try await passkey.delete()
    #expect(engine.userChildMethod == "delete")

    let account = ExternalAccount.mockVerified
    _ = try await account.prepareReauthorization(redirectUrl: "myapp://callback", additionalScopes: ["email"])
    #expect(engine.userChildPick == "externalAccounts")
    #expect(engine.userChildMethod == "reauthorize")
    _ = try await account.destroy()
    #expect(engine.userChildMethod == "destroy")

    #expect(kitCalls.identifierServiceCount == 0)
  }

  @Test
  func sessionRevokeUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSessionService(kitCalls)

    let revoked = try await Session.mock.revoke()
    #expect(engine.listedLocate == "getSessions")
    #expect(engine.listedMethod == "revoke")
    #expect(revoked.id == Session.mock.id)

    _ = try await Clerk.shared.auth.revokeSession(.mock)
    #expect(engine.listedLocate == "getSessions")
    #expect(engine.listedMethod == "revoke")
    #expect(kitCalls.sessionRevokeCount == 0)
  }

  @Test
  func signInAndSignUpReloadUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    var signedIn = SignIn.mock
    signedIn.firstFactorVerification = Verification(status: .verified)
    engine.signInOnReload = signedIn
    let reloadedSignIn = try await SignIn.mock.reload(rotatingTokenNonce: "test_nonce")
    #expect(engine.instanceRoot == "signIn")
    #expect(engine.instanceMethod == "reload")
    #expect(engine.reloadedNonce == "test_nonce")
    #expect(reloadedSignIn.firstFactorVerification?.status == .verified)
    #expect(kitCalls.signInGetCount == 0)

    engine.signUpOnReload = .mock
    let reloadedSignUp = try await SignUp.mock.reload()
    #expect(engine.instanceRoot == "signUp")
    #expect(engine.instanceMethod == "reload")
    #expect(engine.reloadedNonce == nil)
    #expect(reloadedSignUp.id == SignUp.mock.id)
    #expect(kitCalls.signUpGetCount == 0)
  }

  @Test
  func billingReadsUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingBillingService(kitCalls)

    let plans = try await Clerk.shared.billing.getPlans(
      params: .init(for: .organization, orgId: "org_123", minSeats: 5, initialPage: 3, pageSize: 10)
    )
    #expect(engine.instanceRoot == "billing")
    #expect(engine.instanceMethod == "getPlans")
    #expect(engine.instanceArgsObject["for"] as? String == "organization")
    #expect(engine.instanceArgsObject["orgId"] as? String == "org_123")
    #expect(engine.instanceArgsObject["minSeats"] as? Int == 5)
    #expect(engine.instanceArgsObject["initialPage"] as? Int == 3)
    #expect(plans.data.first?.id == BillingPlan.mock.id)

    _ = try await Clerk.shared.billing.getPlan(params: .init(id: "plan_1"))
    _ = try await Clerk.shared.billing.getSubscription(params: .init(orgId: "org_123"))
    _ = try await Clerk.shared.billing.getStatements(params: .init())
    _ = try await Clerk.shared.billing.getStatement(params: .init(id: "stmt_1"))
    _ = try await Clerk.shared.billing.getPaymentAttempts(params: .init())
    _ = try await Clerk.shared.billing.getPaymentAttempt(params: .init(id: "pay_1"))
    _ = try await Clerk.shared.billing.getCreditBalance(params: .init())
    _ = try await Clerk.shared.billing.getCreditHistory(params: .init())
    _ = try await User.mock.getPaymentMethods()
    #expect(engine.instanceRoot == "user")
    #expect(engine.instanceMethod == "getPaymentMethods")
    _ = try await Organization.mock.getPaymentMethods()
    #expect(engine.organizationMethodId == Organization.mock.id)
    #expect(engine.organizationMethodName == "getPaymentMethods")
    #expect(kitCalls.billingServiceCount == 0)
  }

  @Test
  @available(*, deprecated)
  func deprecatedUserUpdateSendsUnsafeMetadataThroughEngine() async throws {
    let engine = RecordingEngineClient()
    Clerk.engineClient = engine
    engine.publish(User.mock)
    let user = try #require(Clerk.shared.user)

    _ = try await user.update(.init(firstName: "Ada", unsafeMetadata: ["theme": "dark"]))
    #expect(engine.updatedFirstName == "Ada")
    #expect(engine.updatedUnsafeMetadata == ["theme": "dark"])
  }

  #if !os(tvOS) && !os(watchOS)
  @Test
  func startEnterpriseSSOUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)

    let signIn = try await Clerk.shared.auth.startEnterpriseSSO(
      emailAddress: "user@enterprise.com",
      redirectUrl: "myapp://callback"
    )

    #expect(engine.startedEnterpriseSSOEmail == "user@enterprise.com")
    #expect(engine.startedEnterpriseSSORedirectUrl == "myapp://callback")
    #expect(signIn.id == "sia_engine")
    #expect(signIn.firstFactorVerification?.factorStrategy == .enterpriseSSO)
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.prepareCount == 0)
  }

  @Test
  func emailLinkUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    let signIn = try await Clerk.shared.auth.signInWithEmailLink(emailAddress: " user@example.com ")
    #expect(engine.signedInIdentifier == "user@example.com")
    #expect(engine.sentEmailLinkAddressId == "idn_email")
    #expect(engine.sentEmailLinkChallengeMethod == PKCE.codeChallengeMethod)
    #expect(engine.sentEmailLinkChallenge?.isEmpty == false)
    #expect(signIn.firstFactorVerification?.factorStrategy == .emailLink)
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.prepareCount == 0)

    engine.publish(SignUp.mock)
    let signUp = try #require(Clerk.shared.auth.currentSignUp)
    _ = try await signUp.sendEmailLink()
    #expect(engine.sentSignUpEmailLinkChallenge?.isEmpty == false)
    #expect(kitCalls.signUpCreateCount == 0)
  }

  @Test
  func signUpOAuthAndEnterpriseSSOUseEngineAndSkipKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignUpService(kitCalls)

    let oauth = try await Clerk.shared.auth.signUpWithOAuth(provider: .google)
    #expect(engine.signUpRedirectStrategy == "oauth_google")
    #expect(engine.signUpRedirectEmail == nil)
    if case .signUp(let signUp) = oauth {
      #expect(signUp.id == SignUp.mock.id)
    } else {
      Issue.record("Expected a sign-up transfer result")
    }

    let sso = try await Clerk.shared.auth.signUpWithEnterpriseSSO(emailAddress: "user@enterprise.com")
    #expect(engine.signUpRedirectStrategy == "enterprise_sso")
    #expect(engine.signUpRedirectEmail == "user@enterprise.com")
    if case .signUp(let signUp) = sso {
      #expect(signUp.id == SignUp.mock.id)
    } else {
      Issue.record("Expected a sign-up transfer result")
    }
    #expect(kitCalls.signUpCreateCount == 0)
  }
  #endif

  @Test
  func transferUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSignInService(kitCalls)
    installFailingSignUpService(kitCalls)

    let metadata: JSON = ["plan": "pro"]
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)
    let toSignUp = try await signIn.handleTransferFlow(
      transferable: true,
      unsafeMetadata: metadata
    )
    #expect(engine.transferredToSignUpMetadata == metadata)
    if case .signUp(let signUp) = toSignUp {
      #expect(signUp.id == SignUp.mock.id)
    } else {
      Issue.record("Expected a sign-up transfer result")
    }
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.signUpCreateCount == 0)

    var signUp = SignUp.mock
    signUp.verificationByAttribute = ["external_account": Verification(status: .transferable)]
    let toSignIn = try await signUp.handleTransferFlow()
    #expect(engine.transferredToSignIn)
    if case .signIn(let transferred) = toSignIn {
      #expect(transferred.id == "sia_engine")
    } else {
      Issue.record("Expected a sign-in transfer result")
    }
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.signUpCreateCount == 0)
  }

  @Test
  func signInWithEmailCodeThrowsWhenEngineIsUnavailable() async {
    #expect(Clerk.engineClient == nil)
    #expect(Clerk.makeEngineClient == nil)
    await #expect(throws: ClerkClientError.self) {
      try await Clerk.shared.auth.signInWithEmailCode(emailAddress: "user@example.com")
    }
  }

  @Test
  func configureDoesNotInstallEngineInTests() async {
    #expect(Clerk.makeEngineClient == nil)
    #expect(await Clerk.resolvedEngineClient() == nil)
  }

  @Test
  func resolvedEngineClientCreatesOnceFromFactory() async {
    var creations = 0
    Clerk.makeEngineClient = { _ in
      creations += 1
      return RecordingEngineClient()
    }

    let first = await Clerk.resolvedEngineClient()
    let second = await Clerk.resolvedEngineClient()

    #expect(creations == 1)
    #expect(first != nil)
    #expect(second != nil)
  }

  @Test
  func sessionVerificationUsesEngineAndSkipsKitFAPI() async throws {
    let engine = RecordingEngineClient()
    let kitCalls = KitCallCounter()
    Clerk.engineClient = engine
    installFailingSessionService(kitCalls)

    let session = Session.mock
    let started = try await session.startVerification(level: .firstFactor)
    #expect(engine.sessionVerificationLevel == "first_factor")
    #expect(started.status == .needsFirstFactor)

    let emailed = try await session.sendEmailCode(emailAddressId: "idn_email")
    #expect(engine.sessionFirstFactorStrategy == "email_code")
    #expect(engine.sessionFirstFactorEmailAddressId == "idn_email")
    #expect(emailed.status == .needsFirstFactor)

    let password = try await session.verifyWithPassword("hunter2")
    #expect(engine.sessionFirstFactorStrategy == "password")
    #expect(engine.sessionFirstFactorPassword == "hunter2")
    #expect(password.status == .complete)

    let sso = try await session.startEnterpriseSSO(
      emailAddressId: "idn_email",
      enterpriseConnectionId: "econn_123",
      redirectUrl: "myapp://callback"
    )
    #expect(engine.sessionFirstFactorStrategy == "enterprise_sso")
    #expect(engine.sessionFirstFactorEnterpriseConnectionId == "econn_123")
    #expect(engine.sessionFirstFactorRedirectUrl == "myapp://callback")
    #expect(sso.status == .needsFirstFactor)

    let mfaPrepared = try await session.sendMfaPhoneCode(phoneNumberId: "idn_phone")
    #expect(engine.sessionSecondFactorStrategy == "phone_code")
    #expect(engine.sessionSecondFactorPhoneNumberId == "idn_phone")
    #expect(mfaPrepared.status == .needsSecondFactor)

    let totp = try await session.verifyWithTOTP(code: "123456")
    #expect(engine.sessionSecondFactorStrategy == "totp")
    #expect(engine.sessionSecondFactorCode == "123456")
    #expect(totp.status == .complete)

    let backup = try await session.verifyWithBackupCode(code: "abcdef")
    #expect(engine.sessionSecondFactorStrategy == "backup_code")
    #expect(engine.sessionSecondFactorCode == "abcdef")
    #expect(backup.status == .complete)

    let passkeySecond = try await session.attemptSecondFactorVerification(
      strategy: .passkey,
      publicKeyCredential: "credential"
    )
    #expect(engine.sessionSecondFactorStrategy == "passkey")
    #expect(engine.sessionSecondFactorPublicKeyCredential == "credential")
    #expect(passkeySecond.status == .complete)

    #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
    let passkeyFirst = try await session.verifyWithPasskey(level: .firstFactor)
    #expect(engine.verifiedSessionWithPasskey)
    #expect(passkeyFirst.status == .complete)
    #endif

    #expect(kitCalls.sessionVerificationCount == 0)
  }
}

@MainActor
final class RecordingEngineClient: ClerkEngineClient {
  var signedInIdentifier: String?
  var signedInEmail: String?
  var signedInPhone: String?
  var passwordIdentifier: String?
  var password: String?
  var sentEmailAddressId: String?
  var sentPhoneNumberId: String?
  var verifiedCode: String?
  var verifiedPhoneCode: String?
  var activeSessionId: String?
  var activeOrganizationId: String?
  var signedOut = false

  func signIn(identifier: String) async throws {
    signedInIdentifier = identifier
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: identifier,
        supportedFirstFactors: [
          Factor(strategy: .emailLink, emailAddressId: "idn_email", safeIdentifier: identifier),
        ]
      )
    )
  }

  func signInWithEmailCode(emailAddress: String) async throws {
    signedInEmail = emailAddress
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: emailAddress,
        firstFactorVerification: Verification(status: .unverified, strategy: .emailCode)
      )
    )
  }

  func signInWithPhoneCode(phoneNumber: String) async throws {
    signedInPhone = phoneNumber
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: phoneNumber,
        firstFactorVerification: Verification(status: .unverified, strategy: .phoneCode)
      )
    )
  }

  func signInWithPassword(identifier: String, password: String) async throws {
    passwordIdentifier = identifier
    self.password = password
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: identifier,
        createdSessionId: "sess_engine"
      )
    )
  }

  func sendEmailCode(emailAddressId: String?) async throws {
    sentEmailAddressId = emailAddressId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .emailCode)
      )
    )
  }

  var sentEmailLinkAddressId: String?
  var sentEmailLinkRedirect: String?
  var sentEmailLinkChallenge: String?
  var sentEmailLinkChallengeMethod: String?
  var sentSignUpEmailLinkRedirect: String?
  var sentSignUpEmailLinkChallenge: String?

  func sendEmailLink(
    emailAddressId: String?,
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod: String
  ) async throws {
    sentEmailLinkAddressId = emailAddressId
    sentEmailLinkRedirect = redirectUrl
    sentEmailLinkChallenge = codeChallenge
    sentEmailLinkChallengeMethod = codeChallengeMethod
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .emailLink)
      )
    )
  }

  func sendSignUpEmailLink(
    redirectUrl: String,
    codeChallenge: String,
    codeChallengeMethod _: String
  ) async throws {
    sentSignUpEmailLinkRedirect = redirectUrl
    sentSignUpEmailLinkChallenge = codeChallenge
    publish(SignUp.mock)
  }

  func sendPhoneCode(phoneNumberId: String?) async throws {
    sentPhoneNumberId = phoneNumberId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "+15555550100",
        firstFactorVerification: Verification(status: .unverified, strategy: .phoneCode)
      )
    )
  }

  func verifyEmailCode(_ code: String) async throws {
    verifiedCode = code
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .verified, strategy: .emailCode),
        createdSessionId: "sess_engine"
      )
    )
  }

  func verifyPhoneCode(_ code: String) async throws {
    verifiedPhoneCode = code
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "+15555550100",
        firstFactorVerification: Verification(status: .verified, strategy: .phoneCode),
        createdSessionId: "sess_engine"
      )
    )
  }

  func authenticateWithPassword(_ password: String) async throws {
    self.password = password
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        createdSessionId: "sess_engine"
      )
    )
  }

  func setActive(sessionId: String, organizationId: String?) async throws {
    activeSessionId = sessionId
    activeOrganizationId = organizationId
    var session = Session.mock
    session.lastActiveOrganizationId = organizationId
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        sessions: [session],
        lastActiveSessionId: session.id,
        updatedAt: Date()
      )
    )
  }

  func signOut(sessionId _: String?) async throws {
    signedOut = true
    Clerk.shared.applyResponseClient(
      Client(id: "client_engine", sessions: [], updatedAt: Date())
    )
  }

  func getToken(template _: String?, skipCache _: Bool) async throws -> String? {
    "jwt_engine"
  }

  var signedUpEmail: String?
  var sentSignUpEmailCode = false
  var verifiedSignUpEmailCode: String?

  func signUp(
    emailAddress: String?,
    password _: String?,
    firstName _: String?,
    lastName _: String?,
    username _: String?,
    phoneNumber _: String?,
    legalAccepted _: Bool?,
    transfer _: Bool
  ) async throws {
    signedUpEmail = emailAddress
    var signUp = SignUp.mock
    signUp.emailAddress = emailAddress
    signUp.status = .missingRequirements
    publish(signUp)
  }

  func sendSignUpEmailCode() async throws {
    sentSignUpEmailCode = true
    var signUp = SignUp.mock
    signUp.emailAddress = "user@example.com"
    publish(signUp)
  }

  func sendSignUpPhoneCode() async throws {
    let signUp = SignUp.mock
    publish(signUp)
  }

  func verifySignUpEmailCode(_ code: String) async throws {
    verifiedSignUpEmailCode = code
    var signUp = SignUp.mock
    signUp.status = .complete
    signUp.createdSessionId = "sess_engine"
    publish(signUp)
  }

  func verifySignUpPhoneCode(_: String) async throws {
    var signUp = SignUp.mock
    signUp.status = .complete
    signUp.createdSessionId = "sess_engine"
    publish(signUp)
  }

  var signedInTicket: String?
  var signedInIdToken: String?
  var signedInIdTokenStrategy: String?
  var signedUpTicket: String?

  func signInWithTicket(_ ticket: String) async throws {
    signedInTicket = ticket
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  var signInPublishedByIdToken: SignIn?
  var signUpWithIdTokenError: (any Error)?
  var signUpPublishedByIdToken = SignUp.mock
  var signInPublishedBySignUpIdToken: SignIn?
  var signedUpIdToken: String?
  var signedUpIdTokenStrategy: String?
  var signedUpFirstName: String?
  var signedUpLastName: String?

  func signInWithIdToken(strategy: String, token: String) async throws {
    signedInIdTokenStrategy = strategy
    signedInIdToken = token
    publish(
      signInPublishedByIdToken
        ?? SignIn(
          id: "sia_engine",
          status: .complete,
          createdSessionId: "sess_engine"
        )
    )
  }

  func authenticateWithIdToken(strategy: String, token: String) async throws {
    signedInIdTokenStrategy = strategy
    signedInIdToken = token
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  func signUpWithTicket(_ ticket: String) async throws {
    signedUpTicket = ticket
    publish(SignUp.mock)
  }

  func signUpWithIdToken(strategy: String, token: String, firstName: String?, lastName: String?) async throws {
    if let signUpWithIdTokenError {
      throw signUpWithIdTokenError
    }
    signedUpIdTokenStrategy = strategy
    signedUpIdToken = token
    signedUpFirstName = firstName
    signedUpLastName = lastName
    if let signInPublishedBySignUpIdToken {
      publish(signInPublishedBySignUpIdToken)
    } else {
      publish(signUpPublishedByIdToken)
    }
  }

  var redirectStrategy: String?
  var startedEnterpriseSSOEmail: String?
  var startedEnterpriseSSORedirectUrl: String?
  var signUpRedirectStrategy: String?
  var signUpRedirectEmail: String?
  var resetEmailAddressId: String?
  var resetPhoneNumberId: String?
  var verifiedResetCode: String?
  var resetPassword: String?
  var resetSignOutOfOtherSessions: Bool?
  var sentMfaEmailAddressId: String?
  var sentMfaPhoneNumberId: String?
  var verifiedMfaCode: String?
  var verifiedMfaType: SignIn.MfaType?
  var authenticatedPasskey = false
  var updatedSignUpFirstName: String?
  var updatedSignUpLastName: String?

  func authenticateWithRedirect(strategy: String, redirectUrl _: String, identifier _: String?) async throws {
    redirectStrategy = strategy
    publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: "user@example.com")
    )
  }

  func startEnterpriseSSO(emailAddress: String, redirectUrl: String) async throws {
    startedEnterpriseSSOEmail = emailAddress
    startedEnterpriseSSORedirectUrl = redirectUrl
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: emailAddress,
        firstFactorVerification: Verification(
          status: .unverified,
          strategy: .enterpriseSSO,
          externalVerificationRedirectUrl: "https://sso.example.com"
        )
      )
    )
  }

  func authenticateSignUpWithRedirect(strategy: String, redirectUrl _: String, emailAddress: String?) async throws {
    signUpRedirectStrategy = strategy
    signUpRedirectEmail = emailAddress
    publish(SignUp.mock)
  }

  func createPasskeySignIn() async throws {
    publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: nil)
    )
  }

  func authenticateWithPasskey(autofill _: Bool) async throws {
    authenticatedPasskey = true
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        createdSessionId: "sess_engine"
      )
    )
  }

  func sendMfaPhoneCode(phoneNumberId: String?) async throws {
    sentMfaPhoneNumberId = phoneNumberId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsSecondFactor,
        identifier: "user@example.com",
        secondFactorVerification: Verification(status: .unverified, strategy: .phoneCode)
      )
    )
  }

  func sendMfaEmailCode(emailAddressId: String?) async throws {
    sentMfaEmailAddressId = emailAddressId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsSecondFactor,
        identifier: "user@example.com",
        secondFactorVerification: Verification(status: .unverified, strategy: .emailCode)
      )
    )
  }

  func verifyMfaCode(_ code: String, type: SignIn.MfaType) async throws {
    verifiedMfaCode = code
    verifiedMfaType = type
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        createdSessionId: "sess_engine"
      )
    )
  }

  func sendResetPasswordEmailCode(emailAddressId: String?) async throws {
    resetEmailAddressId = emailAddressId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .resetPasswordEmailCode)
      )
    )
  }

  func sendResetPasswordPhoneCode(phoneNumberId: String?) async throws {
    resetPhoneNumberId = phoneNumberId
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .unverified, strategy: .resetPasswordPhoneCode)
      )
    )
  }

  func verifyResetPasswordCode(_ code: String, isEmail _: Bool) async throws {
    verifiedResetCode = code
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsNewPassword,
        identifier: "user@example.com",
        firstFactorVerification: Verification(status: .verified, strategy: .resetPasswordEmailCode)
      )
    )
  }

  func resetPassword(password: String, signOutOfOtherSessions: Bool) async throws {
    resetPassword = password
    resetSignOutOfOtherSessions = signOutOfOtherSessions
    publish(
      SignIn(
        id: "sia_engine",
        status: .complete,
        identifier: "user@example.com",
        createdSessionId: "sess_engine"
      )
    )
  }

  func updateSignUp(
    emailAddress _: String?,
    password _: String?,
    firstName: String?,
    lastName: String?,
    username _: String?,
    phoneNumber _: String?,
    legalAccepted _: Bool?
  ) async throws {
    updatedSignUpFirstName = firstName
    updatedSignUpLastName = lastName
    var signUp = SignUp.mock
    signUp.firstName = firstName
    signUp.lastName = lastName
    publish(signUp)
  }

  var updatedUsername: String?
  var updatedFirstName: String?
  var updatedLastName: String?
  var updatedPrimaryEmailAddressId: String?
  var updatedPrimaryPhoneNumberId: String?
  var updatedUnsafeMetadata: JSON?
  var updatedPasswordCurrent: String?
  var updatedPasswordNew: String?
  var updatedPasswordSignOutOfOtherSessions: Bool?
  var createdEmail: String?
  var createdPhone: String?
  var verifiedTotpCode: String?
  var deletedUser = false

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

  var reloadedUser = false
  var updatedMetadata: JSON?
  var createdBackupCodes = false
  var disabledTOTP = false
  var createdExternalAccountStrategy: String?
  var createdExternalAccountRedirectUrl: String?
  var createdExternalAccountScopes: [String]?
  var createdExternalAccountPrompt: String?
  var createdExternalAccountToken: String?
  var createdPasskey = false
  var createdOrganizationName: String?
  var createdOrganizationSlug: String?
  var fetchedOrganizationId: String?

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

  var organizationMethodId: String?
  var organizationMethodName: String?
  var organizationMethodArgs: Data?

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

  var instanceRoot: String?
  var instanceMethod: String?
  var instanceArgs: Data?
  var allInstanceMethods: [String] = []
  var instanceMethodErrors: [String: any Error] = [:]
  var reloadedNonce: String?
  var signInOnReload = SignIn.mock
  var signUpOnReload = SignUp.mock

  var instanceArgsObject: [String: Any] {
    jsonObject(instanceArgs)
  }

  var userChildPick: String?
  var userChildId: String?
  var userChildMethod: String?

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

  var listedOrganizationId: String?
  var listedLocate: String?
  var listedMethod: String?

  func callListedChild(
    organizationId: String?,
    locate: String,
    locateArgs _: Data,
    findId _: String?,
    method: String,
    args _: Data
  ) async throws -> Data {
    listedOrganizationId = organizationId
    listedLocate = locate
    listedMethod = method
    if method == "delete" || method == "destroy" {
      return Data(#"{"object":"deleted","id":"1","deleted":true}"#.utf8)
    }
    switch locate {
    case "getInvitations":
      return try JSONEncoder.clerkEncoder.encode(OrganizationInvitation.mock)
    case "getDomain":
      return try JSONEncoder.clerkEncoder.encode(OrganizationDomain.mock)
    case "getOrganizationInvitations":
      return try JSONEncoder.clerkEncoder.encode(UserOrganizationInvitation.mock)
    case "getOrganizationSuggestions":
      return try JSONEncoder.clerkEncoder.encode(OrganizationSuggestion.mock)
    case "getMembershipRequests":
      return try JSONEncoder.clerkEncoder.encode(OrganizationMembershipRequest.mock)
    case "getSessions":
      return try JSONEncoder.clerkEncoder.encode(Session.mock)
    default:
      throw ClerkClientError(message: "Unexpected listed child \(locate)")
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

  var fetchedInvitationPage: Int?
  var fetchedInvitationPageSize: Int?
  var fetchedInvitationStatus: [String]?
  var fetchedMembershipPage: Int?
  var fetchedMembershipPageSize: Int?
  var fetchedSuggestionPage: Int?
  var fetchedSuggestionPageSize: Int?
  var fetchedSuggestionStatus: [String]?
  var fetchedSessions = false
  var leftOrganizationId: String?
  var fetchedCreationDefaults = false

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

  var transferredToSignUpMetadata: JSON?
  var transferredToSignIn = false

  func transferToSignUp(unsafeMetadata: JSON?) async throws {
    transferredToSignUpMetadata = unsafeMetadata
    publish(SignUp.mock)
  }

  func transferToSignIn() async throws {
    transferredToSignIn = true
    publish(
      SignIn(
        id: "sia_engine",
        status: .needsFirstFactor,
        identifier: "user@example.com"
      )
    )
  }

  var sessionVerificationLevel: String?
  var sessionFirstFactorStrategy: String?
  var sessionFirstFactorEmailAddressId: String?
  var sessionFirstFactorPhoneNumberId: String?
  var sessionFirstFactorEnterpriseConnectionId: String?
  var sessionFirstFactorRedirectUrl: String?
  var sessionFirstFactorCode: String?
  var sessionFirstFactorPassword: String?
  var sessionSecondFactorStrategy: String?
  var sessionSecondFactorPhoneNumberId: String?
  var sessionSecondFactorCode: String?
  var sessionSecondFactorPublicKeyCredential: String?
  var verifiedSessionWithPasskey = false

  func startSessionVerification(level: String) async throws -> SessionVerification {
    sessionVerificationLevel = level
    return .mockNeedsFirstFactor
  }

  func prepareSessionFirstFactor(
    strategy: String,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification {
    sessionFirstFactorStrategy = strategy
    sessionFirstFactorEmailAddressId = emailAddressId
    sessionFirstFactorPhoneNumberId = phoneNumberId
    sessionFirstFactorEnterpriseConnectionId = enterpriseConnectionId
    sessionFirstFactorRedirectUrl = redirectUrl
    return .mockNeedsFirstFactor
  }

  func attemptSessionFirstFactor(
    strategy: String,
    code: String?,
    password: String?,
    publicKeyCredential _: String?
  ) async throws -> SessionVerification {
    sessionFirstFactorStrategy = strategy
    sessionFirstFactorCode = code
    sessionFirstFactorPassword = password
    return .mockComplete
  }

  func prepareSessionSecondFactor(strategy: String, phoneNumberId: String?) async throws -> SessionVerification {
    sessionSecondFactorStrategy = strategy
    sessionSecondFactorPhoneNumberId = phoneNumberId
    return .mockNeedsSecondFactor
  }

  func attemptSessionSecondFactor(
    strategy: String,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    sessionSecondFactorStrategy = strategy
    sessionSecondFactorCode = code
    sessionSecondFactorPublicKeyCredential = publicKeyCredential
    return .mockComplete
  }

  func verifySessionWithPasskey() async throws -> SessionVerification {
    verifiedSessionWithPasskey = true
    return .mockComplete
  }

  var lastJSMethod: String?

  private var currentUser: User {
    Clerk.shared.user ?? .mock
  }

  func publish(_ signIn: SignIn) {
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        signIn: signIn,
        sessions: [],
        updatedAt: Date()
      )
    )
  }

  func publish(_ signUp: SignUp) {
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        signUp: signUp,
        sessions: [],
        updatedAt: Date()
      )
    )
  }

  func publish(_ user: User) {
    var session = Session.mock
    session.user = user
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        sessions: [session],
        lastActiveSessionId: session.id,
        updatedAt: Date()
      )
    )
  }
}

@MainActor
private final class KitCallCounter {
  var createCount = 0
  var prepareCount = 0
  var attemptCount = 0
  var setActiveCount = 0
  var signOutCount = 0
  var prepareSecondCount = 0
  var attemptSecondCount = 0
  var resetPasswordCount = 0
  var signUpUpdateCount = 0
  var signUpCreateCount = 0
  var userServiceCount = 0
  var organizationServiceCount = 0
  var identifierServiceCount = 0
  var sessionVerificationCount = 0
  var sessionRevokeCount = 0
  var signInGetCount = 0
  var signUpGetCount = 0
  var billingServiceCount = 0
}

@MainActor
private func installFailingSignInService(_ counts: KitCallCounter) {
  let service = MockSignInService(
    create: { _ in
      counts.createCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    attemptFirstFactor: { _, _ in
      counts.attemptCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    }
  )
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    signInService: service
  )
  try! (Clerk.shared.dependencies as! MockDependencyContainer)
    .configurationManager
    .configure(publishableKey: testPublishableKey, options: .init())
}

@MainActor
private func installFailingSessionService(_ counts: KitCallCounter) {
  let service = MockSessionService(
    setActive: { _, _ in
      counts.setActiveCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    }
  )
  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: createMockAPIClient(),
    signInService: Clerk.shared.dependencies.signInService,
    sessionService: service
  )
  try! (Clerk.shared.dependencies as! MockDependencyContainer)
    .configurationManager
    .configure(publishableKey: testPublishableKey, options: .init())
}

@MainActor
private func installFailingSignUpService(_ counts: KitCallCounter) {
  _ = counts
}

@MainActor
private func installFailingUserService(_ counts: KitCallCounter) {
  _ = counts
}

@MainActor
private func installFailingOrganizationService(_ counts: KitCallCounter) {
  _ = counts
}

@MainActor
private func installFailingIdentifierServices(_ counts: KitCallCounter) {
  _ = counts
}

@MainActor
private func installFailingBillingService(_ counts: KitCallCounter) {
  _ = counts
}

private func jsonObject(_ data: Data?) -> [String: Any] {
  guard let data,
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  else {
    return [:]
  }
  return object
}
