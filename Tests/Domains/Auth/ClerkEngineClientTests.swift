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
    #expect(prepared.firstFactorVerification?.strategy == .emailCode)

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
    #expect(kitCalls.createCount == 0)
    #expect(kitCalls.setActiveCount == 0)
    #expect(kitCalls.fetchTokenCount == 0)
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
}

@MainActor
private final class RecordingEngineClient: ClerkEngineClient {
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

  func signIn(identifier: String) async throws {
    signedInIdentifier = identifier
    publish(
      SignIn(id: "sia_engine", status: .needsFirstFactor, identifier: identifier)
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
  }

  func getToken(template _: String?, skipCache _: Bool) async throws -> String? {
    "jwt_engine"
  }

  private func publish(_ signIn: SignIn) {
    Clerk.shared.applyResponseClient(
      Client(
        id: "client_engine",
        signIn: signIn,
        sessions: [],
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
  var fetchTokenCount = 0
}

@MainActor
private func installFailingSignInService(_ counts: KitCallCounter) {
  let service = MockSignInService(
    create: { _ in
      counts.createCount += 1
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    },
    prepareFirstFactor: { _, _ in
      counts.prepareCount += 1
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
    },
    fetchToken: { _, _, _ in
      counts.fetchTokenCount += 1
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
