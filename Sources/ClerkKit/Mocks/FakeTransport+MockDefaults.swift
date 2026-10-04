//
//  FakeTransport+MockDefaults.swift
//  Clerk
//

import Foundation

extension FakeTransport {
  /// A transport that answers every endpoint with its `.mock` fixture until a stub overrides it.
  package static func mockDefaults() -> FakeTransport { // swiftlint:disable:this function_body_length
    let transport = FakeTransport()
    let anyId = FakeTransport.anyPathSegment

    transport.fallback(ClientAPI.get(), returning: ClientResponse(response: Client.mock, client: nil))

    transport.fallback(EnvironmentAPI.get(), returning: .mock)

    transport.fallback(UserAPI.reload(), returning: ClientResponse(response: User.mock, client: nil))
    transport.fallback(UserAPI.update(params: .init()), returning: ClientResponse(response: User.mock, client: nil))
    transport.fallback(UserAPI.updateMetadata(params: .init(unsafeMetadata: .object([:]))), returning: ClientResponse(response: User.mock, client: nil))
    transport.fallback(UserAPI.createBackupCodes(), returning: ClientResponse(response: BackupCodeResource.mock, client: nil))
    transport.fallback(
      UserAPI.createExternalAccount(provider: .google, redirectUrl: "", additionalScopes: [], oidcPrompts: []),
      returning: ClientResponse(response: ExternalAccount.mockVerified, client: nil)
    )
    transport.fallback(UserAPI.createExternalAccountToken(provider: .apple, idToken: ""), returning: ClientResponse(response: ExternalAccount.mockVerified, client: nil))
    transport.fallback(UserAPI.createTotp(), returning: ClientResponse(response: TOTPResource.mock, client: nil))
    transport.fallback(UserAPI.verifyTotp(code: ""), returning: ClientResponse(response: TOTPResource.mock, client: nil))
    transport.fallback(UserAPI.disableTotp(), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(
      UserAPI.getOrganizationInvitations(offset: 0, pageSize: 0, status: []),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [UserOrganizationInvitation.mock], totalCount: 1), client: nil)
    )
    transport.fallback(
      UserAPI.getOrganizationMemberships(offset: 0, pageSize: 0),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationMembership.mockWithUserData], totalCount: 1), client: nil)
    )
    transport.fallback(UserAPI.leaveOrganization(organizationId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(
      UserAPI.getOrganizationSuggestions(offset: 0, pageSize: 0, status: []),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationSuggestion.mock], totalCount: 1), client: nil)
    )
    transport.fallback(
      UserAPI.getOrganizationCreationDefaults(),
      returning: ClientResponse(
        response: OrganizationCreationDefaults(
          advisory: nil,
          form: .init(name: "My organization", slug: "my-organization", logo: nil, blurHash: nil)
        ),
        client: nil
      )
    )
    transport.fallback(UserAPI.getSessions(), returning: [Session.mock, Session.mock2])
    transport.fallback(UserAPI.updatePassword(params: .init(newPassword: "", signOutOfOtherSessions: false)), returning: ClientResponse(response: User.mock, client: nil))
    transport.fallback(
      UserAPI.setProfileImage(boundary: ""),
      returning: ClientResponse(response: ImageResource(id: "mock-image-id", name: "mock-image", publicUrl: nil), client: nil)
    )
    transport.fallback(UserAPI.deleteProfileImage(), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(UserAPI.delete(), returning: ClientResponse(response: DeletedObject.mock, client: nil))

    transport.fallback(EmailAddressAPI.create(email: EmailAddress.mock.emailAddress), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.fallback(EmailAddressAPI.prepareVerification(emailAddressId: anyId, strategy: .emailCode), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.fallback(EmailAddressAPI.attemptVerification(emailAddressId: anyId, strategy: .emailCode(code: "424242")), returning: ClientResponse(response: EmailAddress.mock, client: nil))
    transport.fallback(EmailAddressAPI.destroy(emailAddressId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))

    transport.fallback(PhoneNumberAPI.create(phoneNumber: PhoneNumber.mock.phoneNumber), returning: ClientResponse(response: PhoneNumber.mock, client: nil))
    transport.fallback(PhoneNumberAPI.delete(phoneNumberId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(PhoneNumberAPI.prepareVerification(phoneNumberId: anyId), returning: ClientResponse(response: PhoneNumber.mock, client: nil))
    transport.fallback(PhoneNumberAPI.attemptVerification(phoneNumberId: anyId, code: ""), returning: ClientResponse(response: PhoneNumber.mock, client: nil))
    transport.fallback(PhoneNumberAPI.makeDefaultSecondFactor(phoneNumberId: anyId), returning: ClientResponse(response: PhoneNumber.mock, client: nil))
    transport.fallback(PhoneNumberAPI.setReservedForSecondFactor(phoneNumberId: anyId, reserved: true), returning: ClientResponse(response: PhoneNumber.mock, client: nil))

    transport.fallback(
      ExternalAccountAPI.reauthorize(externalAccountId: anyId, redirectUrl: "", additionalScopes: [], oidcPrompts: []),
      returning: ClientResponse(response: ExternalAccount.mockVerified, client: nil)
    )
    transport.fallback(ExternalAccountAPI.destroy(externalAccountId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))

    transport.fallback(
      MagicLinkAPI.complete(params: MagicLinkCompleteParams(flowId: anyId, approvalToken: "", codeVerifier: "")),
      returning: ClientResponse(response: .ticket(MagicLinkCompleteResponse(flowId: nil, ticket: "ticket_mock")), client: nil)
    )

    transport.fallback(
      HostedAuthAPI.create(params: HostedAuthCreateParams(redirectUrl: "", codeChallenge: "", state: "", mode: nil)),
      returning: ClientResponse(response: HostedAuthResource(object: "hosted_auth", url: "https://accounts.example.com/sign-in"), client: nil)
    )
    transport.fallback(
      HostedAuthAPI.redeem(params: HostedAuthRedeemParams(rotatingTokenNonce: "", codeVerifier: "")),
      returning: ClientResponse<Client?>(response: .mock, client: nil)
    )

    transport.fallback(SessionAPI.revoke(sessionId: anyId), returning: ClientResponse(response: Session.mock, client: nil))
    transport.fallback(SessionAPI.remove(sessionId: anyId), returning: EmptyResponse())
    transport.fallback(SessionAPI.removeAll(), returning: EmptyResponse())
    transport.fallback(SessionAPI.touch(sessionId: anyId, organizationId: nil), returning: ClientResponse(response: Session.mock, client: nil))
    transport.fallback(SessionAPI.fetchToken(sessionId: anyId, template: nil, params: nil), returning: .mock)
    transport.fallback(SessionAPI.fetchToken(sessionId: anyId, template: anyId, params: nil), returning: .mock)
    transport.fallback(SessionAPI.startVerification(sessionId: anyId, params: .init(level: .firstFactor)), returning: ClientResponse(response: .mockNeedsFirstFactor, client: nil))
    transport.fallback(
      SessionAPI.prepareFirstFactorVerification(sessionId: anyId, params: .init(strategy: .emailCode)),
      returning: ClientResponse(response: .mockNeedsFirstFactor, client: nil)
    )
    transport.fallback(
      SessionAPI.attemptFirstFactorVerification(sessionId: anyId, params: .init(strategy: .emailCode)),
      returning: ClientResponse(response: .mockComplete, client: nil)
    )
    transport.fallback(
      SessionAPI.prepareSecondFactorVerification(sessionId: anyId, params: .init(strategy: .phoneCode)),
      returning: ClientResponse(response: .mockNeedsSecondFactor, client: nil)
    )
    transport.fallback(
      SessionAPI.attemptSecondFactorVerification(sessionId: anyId, params: .init(strategy: .phoneCode)),
      returning: ClientResponse(response: .mockComplete, client: nil)
    )

    transport.fallback(SignInAPI.create(params: .init()), returning: ClientResponse(response: SignIn.mock, client: nil))
    transport.fallback(SignInAPI.prepareFirstFactor(signInId: anyId, params: .init(strategy: .emailCode)), returning: ClientResponse(response: SignIn.mock, client: nil))
    transport.fallback(SignInAPI.attemptFirstFactor(signInId: anyId, params: .init(strategy: .emailCode)), returning: ClientResponse(response: SignIn.mock, client: nil))
    transport.fallback(SignInAPI.prepareSecondFactor(signInId: anyId, params: .init(strategy: .phoneCode)), returning: ClientResponse(response: SignIn.mock, client: nil))
    transport.fallback(SignInAPI.attemptSecondFactor(signInId: anyId, params: .init(strategy: .phoneCode)), returning: ClientResponse(response: SignIn.mock, client: nil))
    transport.fallback(SignInAPI.resetPassword(signInId: anyId, params: .init(password: "")), returning: ClientResponse(response: SignIn.mock, client: nil))
    transport.fallback(SignInAPI.get(signInId: anyId, params: .init()), returning: ClientResponse(response: SignIn.mock, client: nil))

    transport.fallback(SignUpAPI.create(params: .init()), returning: ClientResponse(response: SignUp.mock, client: nil))
    transport.fallback(SignUpAPI.prepareVerification(signUpId: anyId, params: .init(strategy: .emailCode)), returning: ClientResponse(response: SignUp.mock, client: nil))
    transport.fallback(SignUpAPI.attemptVerification(signUpId: anyId, params: .init(strategy: .emailCode, code: "")), returning: ClientResponse(response: SignUp.mock, client: nil))
    transport.fallback(SignUpAPI.update(signUpId: anyId, params: .init()), returning: ClientResponse(response: SignUp.mock, client: nil))
    transport.fallback(SignUpAPI.get(signUpId: anyId, params: .init()), returning: ClientResponse(response: SignUp.mock, client: nil))

    transport.fallback(PasskeyAPI.create(), returning: ClientResponse(response: Passkey.mock, client: nil))
    transport.fallback(PasskeyAPI.update(passkeyId: anyId, name: ""), returning: ClientResponse(response: Passkey.mock, client: nil))
    transport.fallback(PasskeyAPI.attemptVerification(passkeyId: anyId, credential: ""), returning: ClientResponse(response: Passkey.mock, client: nil))
    transport.fallback(PasskeyAPI.delete(passkeyId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))

    transport.fallback(BiometricCredentialAPI.list(), returning: ClientResponse(response: [BiometricCredential.mock], client: nil))
    transport.fallback(
      BiometricCredentialAPI.prepareEnrollment(sessionId: "", params: .init(appIdentifier: "", publicKeyJWK: "")),
      returning: ClientResponse(response: BiometricCredentialChallenge.mock, client: nil)
    )
    transport.fallback(
      BiometricCredentialAPI.attemptEnrollment(sessionId: "", params: .init(appIdentifier: "", publicKeyJWK: "", clientData: "", signature: "")),
      returning: ClientResponse(response: BiometricCredential.mock, client: nil)
    )
    transport.fallback(
      BiometricCredentialAPI.validateSignInCredential(biometricCredentialId: ""),
      returning: ClientResponse(response: BiometricCredentialValidation(valid: true), client: nil)
    )
    transport.fallback(BiometricCredentialAPI.revoke(biometricCredentialId: anyId, sessionId: nil), returning: ClientResponse(response: BiometricCredential.mock, client: nil))

    transport.fallback(OrganizationAPI.create(name: "", slug: nil), returning: ClientResponse(response: Organization.mock, client: nil))
    transport.fallback(OrganizationAPI.get(organizationId: anyId), returning: ClientResponse(response: Organization.mock, client: nil))
    transport.fallback(OrganizationAPI.update(organizationId: anyId, name: "", slug: nil), returning: ClientResponse(response: Organization.mock, client: nil))
    transport.fallback(OrganizationAPI.destroy(organizationId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(OrganizationAPI.setLogo(organizationId: anyId, boundary: ""), returning: ClientResponse(response: Organization.mock, client: nil))
    transport.fallback(OrganizationAPI.deleteLogo(organizationId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(
      OrganizationAPI.getRoles(organizationId: anyId, offset: 0, pageSize: 0),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [RoleResource.mock], totalCount: 1), client: nil)
    )
    transport.fallback(
      OrganizationAPI.getMemberships(organizationId: anyId, query: nil, role: nil, offset: 0, pageSize: 0),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationMembership.mockWithUserData], totalCount: 1), client: nil)
    )
    transport.fallback(OrganizationAPI.addMember(organizationId: anyId, userId: "", role: ""), returning: ClientResponse(response: OrganizationMembership.mockWithUserData, client: nil))
    transport.fallback(OrganizationAPI.updateMember(organizationId: anyId, userId: anyId, role: ""), returning: ClientResponse(response: OrganizationMembership.mockWithUserData, client: nil))
    transport.fallback(OrganizationAPI.removeMember(organizationId: anyId, userId: anyId), returning: ClientResponse(response: OrganizationMembership.mockWithUserData, client: nil))
    transport.fallback(
      OrganizationAPI.getInvitations(organizationId: anyId, offset: 0, pageSize: 0, status: []),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationInvitation.mock], totalCount: 1), client: nil)
    )
    transport.fallback(OrganizationAPI.inviteMember(organizationId: anyId, emailAddress: "", role: ""), returning: ClientResponse(response: OrganizationInvitation.mock, client: nil))
    transport.fallback(OrganizationAPI.inviteMembers(organizationId: anyId, emailAddresses: [], role: ""), returning: ClientResponse(response: [OrganizationInvitation.mock], client: nil))
    transport.fallback(OrganizationAPI.revokeInvitation(organizationId: anyId, invitationId: anyId), returning: ClientResponse(response: OrganizationInvitation.mock, client: nil))
    transport.fallback(OrganizationAPI.createDomain(organizationId: anyId, domainName: ""), returning: ClientResponse(response: OrganizationDomain.mock, client: nil))
    transport.fallback(
      OrganizationAPI.getDomains(organizationId: anyId, offset: 0, pageSize: 0, enrollmentMode: nil),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationDomain.mock], totalCount: 1), client: nil)
    )
    transport.fallback(OrganizationAPI.getDomain(organizationId: anyId, domainId: anyId), returning: ClientResponse(response: OrganizationDomain.mock, client: nil))
    transport.fallback(OrganizationAPI.deleteDomain(organizationId: anyId, domainId: anyId), returning: ClientResponse(response: DeletedObject.mock, client: nil))
    transport.fallback(
      OrganizationAPI.prepareDomainAffiliationVerification(organizationId: anyId, domainId: anyId, affiliationEmailAddress: ""),
      returning: ClientResponse(response: OrganizationDomain.mock, client: nil)
    )
    transport.fallback(
      OrganizationAPI.attemptDomainAffiliationVerification(organizationId: anyId, domainId: anyId, code: ""),
      returning: ClientResponse(response: OrganizationDomain.mock, client: nil)
    )
    transport.fallback(
      OrganizationAPI.updateDomainEnrollmentMode(organizationId: anyId, domainId: anyId, enrollmentMode: "", deletePending: nil),
      returning: ClientResponse(response: OrganizationDomain.mock, client: nil)
    )
    transport.fallback(
      OrganizationAPI.getMembershipRequests(organizationId: anyId, offset: 0, pageSize: 0, status: nil),
      returning: ClientResponse(response: ClerkPaginatedResponse(data: [OrganizationMembershipRequest.mock], totalCount: 1), client: nil)
    )
    transport.fallback(
      OrganizationAPI.acceptMembershipRequest(organizationId: anyId, requestId: anyId),
      returning: ClientResponse(response: OrganizationMembershipRequest.mock, client: nil)
    )
    transport.fallback(
      OrganizationAPI.rejectMembershipRequest(organizationId: anyId, requestId: anyId),
      returning: ClientResponse(response: OrganizationMembershipRequest.mock, client: nil)
    )
    transport.fallback(OrganizationAPI.acceptUserInvitation(invitationId: anyId), returning: ClientResponse(response: UserOrganizationInvitation.mock, client: nil))
    transport.fallback(OrganizationAPI.acceptSuggestion(suggestionId: anyId), returning: ClientResponse(response: OrganizationSuggestion.mock, client: nil))

    transport.fallback(BillingAPI.getPlans(params: .init()), returning: ClerkPaginatedResponse(data: [BillingPlan.mock], totalCount: 1))
    transport.fallback(BillingAPI.getPlan(params: .init(id: anyId)), returning: .mock)
    // Billing payer endpoints are user-scoped without an orgId and organization-scoped with one.
    for orgId in [nil, anyId] {
      transport.fallback(BillingAPI.getPaymentAttempts(params: .init(orgId: orgId)), returning: ClerkPaginatedResponse(data: [BillingPayment.mock], totalCount: 1))
      transport.fallback(BillingAPI.getPaymentAttempt(params: .init(id: anyId, orgId: orgId)), returning: .mock)
      transport.fallback(BillingAPI.getSubscription(params: .init(orgId: orgId)), returning: ClientResponse(response: BillingSubscription.mock, client: nil))
      transport.fallback(
        BillingAPI.getStatements(params: .init(orgId: orgId)),
        returning: ClientResponse(response: ClerkPaginatedResponse(data: [BillingStatement.mock], totalCount: 1), client: nil)
      )
      transport.fallback(BillingAPI.getStatement(params: .init(id: anyId, orgId: orgId)), returning: ClientResponse(response: BillingStatement.mock, client: nil))
      transport.fallback(BillingAPI.getCreditBalance(params: .init(orgId: orgId)), returning: ClientResponse(response: BillingCreditBalance.mock, client: nil))
      transport.fallback(
        BillingAPI.getCreditHistory(params: .init(orgId: orgId)),
        returning: ClientResponse(response: ClerkPaginatedResponse(data: [BillingCreditLedger.mock], totalCount: 1), client: nil)
      )
      transport.fallback(
        BillingAPI.getPaymentMethods(params: .init(), orgId: orgId),
        returning: ClientResponse(response: ClerkPaginatedResponse(data: [BillingPaymentMethod.mock], totalCount: 1), client: nil)
      )
    }

    return transport
  }
}
