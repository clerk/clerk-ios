@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized, .tags(.unit, .compatibility))
struct PublicWrapperCompatibilityTests {
  private let support = SharedClerkTestSupport()

  @Test
  func signInVerifyCodeUsesSharedClerkAuthFacade() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    _ = try support.makeSharedClerk(signInService: service)
    _ = try await signIn.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.code == "123456")
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func signUpSendEmailCodeUsesSharedClerkAuthFacade() async throws {
    let signUp = SignUp.mock
    let captured = LockIsolated<(String, SignUp.PrepareVerificationParams)?>(nil)
    let service = MockSignUpService(prepareVerification: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    _ = try support.makeSharedClerk(signUpService: service)
    _ = try await signUp.sendEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signUp.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func sessionRevokeUsesSharedClerkAuthFacade() async throws {
    let session = Session.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockSessionService(revoke: { sessionId, _ in
      captured.setValue(sessionId)
      return .mock
    })

    _ = try support.makeSharedClerk(sessionService: service)
    _ = try await session.revoke()

    #expect(captured.value == session.id)
  }

  @Test
  func sessionGetTokenUsesSharedClerkAuthFacade() async throws {
    var session = Session.mock
    session.id = "compat-session-\(UUID().uuidString)"
    let captured = LockIsolated<(String, String?)?>(nil)
    let service = MockSessionService(fetchToken: { sessionId, template in
      captured.setValue((sessionId, template))
      return .mock
    })

    _ = try support.makeSharedClerk(sessionService: service)
    let token = try await session.getToken(.init(skipCache: true))

    #expect(token == TokenResource.mock.jwt)
    let params = try #require(captured.value)
    #expect(params.0 == session.id)
    #expect(params.1 == nil)
  }

  @Test
  func userReloadUsesSharedClerkAccountFacade() async throws {
    let called = LockIsolated(false)
    let service = MockUserService(reload: {
      called.setValue(true)
      return .mock
    })

    _ = try support.makeSharedClerk(userService: service)
    _ = try await User.mock.reload()

    #expect(called.value == true)
  }

  @Test
  func userCreateExternalAccountUsesSharedClerkRedirectDefaults() async throws {
    let expectedRedirectUrl = "test-app://compat-callback"
    let options = Clerk.Options(
      redirectConfig: .init(
        redirectUrl: expectedRedirectUrl,
        callbackUrlScheme: "test-app"
      )
    )
    let captured = LockIsolated<(OAuthProvider, String?, [String], [OIDCPrompt])?>(nil)
    let service = MockUserService(createExternalAccount: { provider, redirectUrl, additionalScopes, oidcPrompts in
      captured.setValue((provider, redirectUrl, additionalScopes, oidcPrompts))
      return .mockVerified
    })

    _ = try support.makeSharedClerk(userService: service, options: options)
    _ = try await User.mock.createExternalAccount(provider: .google)

    let params = try #require(captured.value)
    #expect(params.0 == .google)
    #expect(params.1 == expectedRedirectUrl)
    #expect(params.2.isEmpty)
    #expect(params.3.isEmpty)
  }

  @Test
  func emailAddressSendCodeUsesSharedClerkAccountFacade() async throws {
    let emailAddress = EmailAddress.mock
    let captured = LockIsolated<(String, EmailAddress.PrepareStrategy)?>(nil)
    let service = MockEmailAddressService(prepareVerification: { id, strategy in
      captured.setValue((id, strategy))
      return .mock
    })

    _ = try support.makeSharedClerk(emailAddressService: service)
    _ = try await emailAddress.sendCode()

    let params = try #require(captured.value)
    #expect(params.0 == emailAddress.id)
    #expect(params.1 == .emailCode)
  }

  @Test
  func phoneNumberDeleteUsesSharedClerkAccountFacade() async throws {
    let phoneNumber = PhoneNumber.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPhoneNumberService(delete: { phoneNumberId in
      captured.setValue(phoneNumberId)
      return .mock
    })

    _ = try support.makeSharedClerk(phoneNumberService: service)
    _ = try await phoneNumber.delete()

    #expect(captured.value == phoneNumber.id)
  }

  @Test
  func externalAccountDestroyUsesSharedClerkAccountFacade() async throws {
    let externalAccount = ExternalAccount.mockVerified
    let captured = LockIsolated<String?>(nil)
    let service = MockExternalAccountService(destroy: { externalAccountId in
      captured.setValue(externalAccountId)
      return .mock
    })

    _ = try support.makeSharedClerk(externalAccountService: service)
    _ = try await externalAccount.destroy()

    #expect(captured.value == externalAccount.id)
  }

  @Test
  func passkeyDeleteUsesSharedClerkAccountFacade() async throws {
    let passkey = Passkey.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockPasskeyService(delete: { passkeyId in
      captured.setValue(passkeyId)
      return .mock
    })

    _ = try support.makeSharedClerk(passkeyService: service)
    _ = try await passkey.delete()

    #expect(captured.value == passkey.id)
  }

  @Test
  func organizationDestroyUsesSharedClerkOrganizationsFacade() async throws {
    let organization = Organization.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(destroyOrganization: { _, organizationId in
      captured.setValue(organizationId)
      return .mock
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await organization.destroy()

    #expect(captured.value == organization.id)
  }

  @Test
  func organizationMembershipUpdateUsesSharedClerkOrganizationsFacade() async throws {
    let membership = OrganizationMembership.mockWithUserData
    let captured = LockIsolated<(String, String, String)?>(nil)
    let service = MockOrganizationService(updateOrganizationMember: { _, organizationId, userId, role in
      captured.setValue((organizationId, userId, role))
      return .mockWithUserData
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await membership.update(role: "org:admin")

    let params = try #require(captured.value)
    #expect(params.0 == membership.organization.id)
    #expect(params.1 == membership.publicUserData?.userId)
    #expect(params.2 == "org:admin")
  }

  @Test
  func organizationInvitationRevokeUsesSharedClerkOrganizationsFacade() async throws {
    let invitation = OrganizationInvitation.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(revokeOrganizationInvitation: { organizationId, invitationId in
      captured.setValue((organizationId, invitationId))
      return .mock
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await invitation.revoke()

    let params = try #require(captured.value)
    #expect(params.0 == invitation.organizationId)
    #expect(params.1 == invitation.id)
  }

  @Test
  func organizationDomainDeleteUsesSharedClerkOrganizationsFacade() async throws {
    let domain = OrganizationDomain.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(deleteOrganizationDomain: { organizationId, domainId in
      captured.setValue((organizationId, domainId))
      return .mock
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await domain.delete()

    let params = try #require(captured.value)
    #expect(params.0 == domain.organizationId)
    #expect(params.1 == domain.id)
  }

  @Test
  func organizationMembershipRequestAcceptUsesSharedClerkOrganizationsFacade() async throws {
    let request = OrganizationMembershipRequest.mock
    let captured = LockIsolated<(String, String)?>(nil)
    let service = MockOrganizationService(acceptOrganizationMembershipRequest: { organizationId, requestId in
      captured.setValue((organizationId, requestId))
      return .mock
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await request.accept()

    let params = try #require(captured.value)
    #expect(params.0 == request.organizationId)
    #expect(params.1 == request.id)
  }

  @Test
  func userOrganizationInvitationAcceptUsesSharedClerkOrganizationsFacade() async throws {
    let invitation = UserOrganizationInvitation.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(acceptUserOrganizationInvitation: { _, invitationId in
      captured.setValue(invitationId)
      return .mock
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await invitation.accept()

    #expect(captured.value == invitation.id)
  }

  @Test
  func organizationSuggestionAcceptUsesSharedClerkOrganizationsFacade() async throws {
    let suggestion = OrganizationSuggestion.mock
    let captured = LockIsolated<String?>(nil)
    let service = MockOrganizationService(acceptOrganizationSuggestion: { _, suggestionId in
      captured.setValue(suggestionId)
      return .mock
    })

    _ = try support.makeSharedClerk(organizationService: service)
    _ = try await suggestion.accept()

    #expect(captured.value == suggestion.id)
  }
}
