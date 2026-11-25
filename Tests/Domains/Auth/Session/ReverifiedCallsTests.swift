#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ReverifiedCallsTests {
  private let transport = FakeTransport.mockDefaults()
  private let attempts = Attempts()

  init() {
    configureClerkForTesting()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
    )
    Clerk.shared.environment = .mock
    Clerk.shared.client = .mock
  }

  @Test(arguments: GatedCall.all)
  func aGatedCallReverifiesAndRunsAgain(call: GatedCall) async throws {
    let display = AnsweringSheetDisplay(answer: .verify)
    call.stub(transport, attempts)

    try await reverify(display) {
      try await call.run()
    }

    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 2)
  }

  @Test(arguments: GatedCall.all)
  func closingTheSheetIsAQuietCancel(call: GatedCall) async {
    let display = AnsweringSheetDisplay(answer: .close)
    call.stub(transport, attempts)

    let error = await #expect(throws: ReverificationCancelledError.self) {
      try await reverify(display) {
        try await call.run()
      }
    }
    #expect(error?.isUserCancelledError == true)
    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 1)
  }

  @Test
  func aPasskeyIsRequestedAgainAfterReverifying() async {
    let display = AnsweringSheetDisplay(answer: .verify)
    transport.stub(PasskeyAPI.create()) { [attempts] _ in
      attempts.count += 1
      if attempts.count == 1 { throw ClerkAPIError.reverificationRequired }
      throw StopBeforePlatformRegistration()
    }

    await #expect(throws: StopBeforePlatformRegistration.self) {
      try await reverify(display) {
        try await User.mock.createPasskey()
      }
    }
    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 2)
  }

  @Test
  func appleShowsItsSheetOnceWhenTheConnectRunsAgain() async throws {
    let display = AnsweringSheetDisplay(answer: .verify)
    var appleSheets = 0
    let sentTokens = Recorded<String?>()
    transport.stub(UserAPI.createExternalAccountToken(provider: .apple, idToken: "", sessionId: "")) { [attempts] call in
      attempts.count += 1
      sentTokens.values.append(call.body?["token"]?.stringValue)
      if attempts.count == 1 { throw ClerkAPIError.reverificationRequired }
      return ClientResponse(response: ExternalAccount.mockVerified, client: nil)
    }

    try await User.mock.connectAppleAccount(
      reverify: reverifier(display),
      appleIdentityToken: {
        appleSheets += 1
        return "apple_id_token"
      }
    )

    #expect(display.levels == [.secondFactor])
    #expect(appleSheets == 1)
    #expect(sentTokens.values == ["apple_id_token", "apple_id_token"])
  }

  @Test
  func biometricEnrollmentAsksForTouchIDOnlyAfterReverifying() async throws {
    var environment = Clerk.Environment.mock
    environment.authConfig.nativeSettings = .init(apiEnabled: true, biometricSignInEnabled: true)
    Clerk.shared.environment = environment
    var signatures = 0
    let biometricCredentials = BiometricCredentials(
      transport: transport,
      keyManager: MockBiometricCredentialKeyManager(sign: { clientData, _, _ in
        signatures += 1
        return .init(clientData: clientData, signature: "signature")
      }),
      credentialStore: BiometricCredentialLocalStore(keychain: InMemoryKeychain()),
      appIdentifierProvider: { "com.clerk.example" }
    )
    let display = AnsweringSheetDisplay(answer: .verify)
    transport.requireReverificationOnce(
      BiometricCredentialAPI.prepareEnrollment(sessionId: "", params: .init(appIdentifier: "", publicKeyJWK: "")),
      then: ClientResponse(response: BiometricCredentialChallenge.mock, client: nil),
      attempts: attempts
    )

    try await reverify(display) {
      try await biometricCredentials.enroll()
    }

    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 2)
    #expect(signatures == 1)
  }

  @Test
  func revokingThisDevicesBiometricCredentialReverifies() async throws {
    let credentialStore = BiometricCredentialLocalStore(keychain: InMemoryKeychain())
    try credentialStore.save(.mock)
    let biometricCredentials = BiometricCredentials(
      transport: transport,
      keyManager: MockBiometricCredentialKeyManager(),
      credentialStore: credentialStore,
      appIdentifierProvider: { "com.clerk.example" }
    )
    let display = AnsweringSheetDisplay(answer: .verify)
    transport.requireReverificationOnce(
      BiometricCredentialAPI.revoke(biometricCredentialId: FakeTransport.anyPathSegment, sessionId: nil),
      then: ClientResponse(response: BiometricCredential.mock, client: nil),
      attempts: attempts
    )

    try await reverify(display) {
      try await biometricCredentials.revokeCurrentDeviceCredential()
    }

    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 2)
  }

  // MARK: - Session tasks

  @Test(arguments: [true, false])
  func theResetPasswordTaskSetsThePasswordAgainOnlyWhileTheTaskIsPending(sheetResetsThePassword: Bool) async throws {
    Clerk.shared.client = client(withTasks: [.resetPassword])
    let display = AnsweringSheetDisplay(answer: .verify) {
      if sheetResetsThePassword {
        Clerk.shared.client = client(withTasks: [])
      }
    }
    transport.requireReverificationOnce(
      UserAPI.updatePassword(params: .init(newPassword: "", signOutOfOtherSessions: false)),
      then: ClientResponse(response: User.mock, client: nil),
      attempts: attempts
    )

    try await SignInSetNewPasswordView.updatePasswordForResetTask(
      .init(currentPassword: nil, newPassword: "new-password", signOutOfOtherSessions: false),
      of: .mock,
      clerk: .shared,
      reverify: reverifier(display)
    )

    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == (sheetResetsThePassword ? 1 : 2))
  }

  @Test
  func aResetTaskClearedBeforeSubmittingStillSetsThePasswordAfterReverifying() async throws {
    Clerk.shared.client = client(withTasks: [])
    let display = AnsweringSheetDisplay(answer: .verify)
    transport.requireReverificationOnce(
      UserAPI.updatePassword(params: .init(newPassword: "", signOutOfOtherSessions: false)),
      then: ClientResponse(response: User.mock, client: nil),
      attempts: attempts
    )

    try await SignInSetNewPasswordView.updatePasswordForResetTask(
      .init(currentPassword: nil, newPassword: "new-password", signOutOfOtherSessions: false),
      of: .mock,
      clerk: .shared,
      reverify: reverifier(display)
    )

    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 2)
  }

  @Test
  func theResetPasswordTaskAlwaysSendsTheFirstAttempt() async throws {
    Clerk.shared.client = client(withTasks: [])
    let display = AnsweringSheetDisplay(answer: .verify)
    transport.stub(UserAPI.updatePassword(params: .init(newPassword: "", signOutOfOtherSessions: false))) { [attempts] _ in
      attempts.count += 1
      return ClientResponse(response: User.mock, client: nil)
    }

    try await SignInSetNewPasswordView.updatePasswordForResetTask(
      .init(currentPassword: nil, newPassword: "new-password", signOutOfOtherSessions: false),
      of: .mock,
      clerk: .shared,
      reverify: reverifier(display)
    )

    #expect(display.levels.isEmpty)
    #expect(attempts.count == 1)
  }

  @Test
  func aPendingSessionReverifiesAndRunsAgain() async throws {
    var client = Client.mock
    client.sessions[0].status = .pending
    Clerk.shared.client = client
    let display = AnsweringSheetDisplay(answer: .verify)
    transport.requireReverificationOnce(UserAPI.createTotp(), then: ClientResponse(response: TOTPResource.mock, client: nil), attempts: attempts)

    try await reverify(display) {
      try await User.mock.createTOTP()
    }

    #expect(Clerk.shared.session?.status == .pending)
    #expect(display.levels == [.secondFactor])
    #expect(attempts.count == 2)
  }

  @Test
  func theSheetStartsVerifyingAPendingSession() async {
    var session = Session.mock
    session.status = .pending
    let startedSessionIds = Recorded<String>()
    transport.stub(SessionAPI.startVerification(sessionId: FakeTransport.anyPathSegment, params: .init(level: .secondFactor))) { call in
      startedSessionIds.values.append(String(call.path.split(separator: "/")[3]))
      return ClientResponse(response: .mockNeedsFirstFactor, client: nil)
    }
    let flow = ReverificationFlow(level: .secondFactor)

    await flow.start(session: session, hasLocalBiometricCredential: false)

    #expect(startedSessionIds.values == [session.id])
    guard case .ready = flow.phase else {
      Issue.record("Expected the flow to show a factor, got \(flow.phase)")
      return
    }
  }

  private func client(withTasks tasks: [Session.Task]) -> Client {
    var client = Client.mock
    client.sessions[0].status = tasks.isEmpty ? .active : .pending
    client.sessions[0].tasks = tasks
    return client
  }

  private func reverifier(_ display: AnsweringSheetDisplay) -> Reverifier {
    Reverifier(clerk: .shared, presenter: ReverificationPresenter(display: display))
  }

  @discardableResult
  private func reverify<T>(_ display: AnsweringSheetDisplay, _ operation: @MainActor () async throws -> T) async throws -> T {
    try await reverifier(display)(operation)
  }
}

struct GatedCall: CustomTestStringConvertible {
  let name: String
  let stub: @MainActor (FakeTransport, Attempts) -> Void
  let run: @MainActor () async throws -> Void

  var testDescription: String {
    name
  }

  private static let anyId = FakeTransport.anyPathSegment

  static let all: [GatedCall] = [
    GatedCall(name: "delete the account") {
      $0.requireReverificationOnce(UserAPI.delete(), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.delete()
    },
    GatedCall(name: "sign out of another device") {
      $0.requireReverificationOnce(SessionAPI.revoke(sessionId: anyId), then: ClientResponse(response: Session.mock2, client: nil), attempts: $1)
    } run: {
      _ = try await Session.mock2.revoke()
    },
    GatedCall(name: "add an email address") {
      $0.requireReverificationOnce(EmailAddressAPI.create(email: ""), then: ClientResponse(response: EmailAddress.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.createEmailAddress("new+clerk_test@example.com")
    },
    GatedCall(name: "remove an email address") {
      $0.requireReverificationOnce(EmailAddressAPI.destroy(emailAddressId: anyId), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      try await RemoveResource.email(.mock).deleteAction()
    },
    GatedCall(name: "set the primary email address") {
      $0.requireReverificationOnce(UserAPI.update(params: .init()), then: ClientResponse(response: User.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.update(.init(primaryEmailAddressId: EmailAddress.mock.id))
    },
    GatedCall(name: "add a phone number") {
      $0.requireReverificationOnce(PhoneNumberAPI.create(phoneNumber: ""), then: ClientResponse(response: PhoneNumber.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.createPhoneNumber("+15555550100")
    },
    GatedCall(name: "remove a phone number") {
      $0.requireReverificationOnce(PhoneNumberAPI.delete(phoneNumberId: anyId), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      try await RemoveResource.phoneNumber(.mock).deleteAction()
    },
    GatedCall(name: "set the primary phone number") {
      $0.requireReverificationOnce(UserAPI.update(params: .init()), then: ClientResponse(response: User.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.update(.init(primaryPhoneNumberId: PhoneNumber.mock.id))
    },
    GatedCall(name: "make a phone number the default second factor") {
      $0.requireReverificationOnce(PhoneNumberAPI.makeDefaultSecondFactor(phoneNumberId: anyId), then: ClientResponse(response: PhoneNumber.mock, client: nil), attempts: $1)
    } run: {
      _ = try await PhoneNumber.mock.makeDefaultSecondFactor()
    },
    GatedCall(name: "use a phone number for SMS codes") {
      $0.requireReverificationOnce(
        PhoneNumberAPI.setReservedForSecondFactor(phoneNumberId: anyId, reserved: true),
        then: ClientResponse(response: PhoneNumber.mock, client: nil),
        attempts: $1
      )
    } run: {
      _ = try await PhoneNumber.mock.setReservedForSecondFactor()
    },
    GatedCall(name: "stop using a phone number for SMS codes") {
      $0.requireReverificationOnce(
        PhoneNumberAPI.setReservedForSecondFactor(phoneNumberId: anyId, reserved: false),
        then: ClientResponse(response: PhoneNumber.mock, client: nil),
        attempts: $1
      )
    } run: {
      try await RemoveResource.secondFactorPhoneNumber(.mock).deleteAction()
    },
    GatedCall(name: "remove a passkey") {
      $0.requireReverificationOnce(PasskeyAPI.delete(passkeyId: anyId), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      try await RemoveResource.passkey(.mock).deleteAction()
    },
    GatedCall(name: "connect an OAuth account") {
      $0.requireReverificationOnce(
        UserAPI.createExternalAccount(provider: .google, redirectUrl: "", additionalScopes: [], oidcPrompts: []),
        then: ClientResponse(response: ExternalAccount.mockVerified, client: nil),
        attempts: $1
      )
    } run: {
      _ = try await User.mock.createExternalAccount(provider: .google)
    },
    GatedCall(name: "remove a connected account") {
      $0.requireReverificationOnce(ExternalAccountAPI.destroy(externalAccountId: anyId), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      try await RemoveResource.externalAccount(.mockVerified).deleteAction()
    },
    GatedCall(name: "add an authenticator app") {
      $0.requireReverificationOnce(UserAPI.createTotp(), then: ClientResponse(response: TOTPResource.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.createTOTP()
    },
    GatedCall(name: "remove the authenticator app") {
      $0.requireReverificationOnce(UserAPI.disableTotp(), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      try await RemoveResource.totp.deleteAction()
    },
    GatedCall(name: "create backup codes") {
      $0.requireReverificationOnce(UserAPI.createBackupCodes(), then: ClientResponse(response: BackupCodeResource.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.createBackupCodes()
    },
    GatedCall(name: "change the password") {
      $0.requireReverificationOnce(
        UserAPI.updatePassword(params: .init(newPassword: "", signOutOfOtherSessions: false)),
        then: ClientResponse(response: User.mock, client: nil),
        attempts: $1
      )
    } run: {
      _ = try await User.mock.updatePassword(.init(currentPassword: nil, newPassword: "new-password", signOutOfOtherSessions: false))
    },
    GatedCall(name: "change the username") {
      $0.requireReverificationOnce(UserAPI.update(params: .init()), then: ClientResponse(response: User.mock, client: nil), attempts: $1)
    } run: {
      _ = try await User.mock.update(.init(username: "new_username"))
    },
    GatedCall(name: "delete an organization") {
      $0.requireReverificationOnce(OrganizationAPI.destroy(organizationId: anyId), then: ClientResponse(response: DeletedObject.mock, client: nil), attempts: $1)
    } run: {
      _ = try await Organization.mock.destroy()
    },
  ]
}

@MainActor
final class Attempts {
  var count = 0
}

@MainActor
private final class Recorded<Value> {
  var values: [Value] = []
}

private struct StopBeforePlatformRegistration: Error {}

extension ClerkAPIError {
  fileprivate static var reverificationRequired: ClerkAPIError {
    ClerkAPIError(code: "session_reverification_required")
  }
}

extension FakeTransport {
  fileprivate func requireReverificationOnce<Value: Decodable & Sendable>(
    _ request: Request<Value>,
    then value: Value,
    attempts: Attempts
  ) {
    stub(request) { _ in
      attempts.count += 1
      if attempts.count == 1 {
        throw ClerkAPIError.reverificationRequired
      }
      return value
    }
  }
}

@MainActor
private final class AnsweringSheetDisplay: ReverificationSheetDisplay {
  enum Answer {
    case verify
    case close
  }

  private let answer: Answer
  private let whileShown: @MainActor () -> Void
  private(set) var levels: [SessionVerification.Level] = []

  init(answer: Answer, whileShown: @escaping @MainActor () -> Void = {}) {
    self.answer = answer
    self.whileShown = whileShown
  }

  func show(
    _ request: ReverificationRequest,
    clerk _: Clerk,
    onDismiss: @escaping @MainActor () -> Void
  ) async -> Bool {
    levels.append(request.level)
    whileShown()
    if answer == .verify {
      request.markComplete()
    }
    onDismiss()
    return true
  }
}

#endif
