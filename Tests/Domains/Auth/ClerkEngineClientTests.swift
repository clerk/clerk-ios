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
    let prepared = try try await #require(Clerk.shared.auth.currentSignIn?.sendEmailCode(emailAddressId: "idn_email"))
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
  var signedInEmail: String?
  var sentEmailAddressId: String?
  var verifiedCode: String?

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
