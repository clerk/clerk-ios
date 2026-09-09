#if os(iOS) || os(macOS)
@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor @Suite(.serialized) struct AuthFlowCoreTests {
  private func connect(_ fixture: FixtureCapabilities) async throws -> Clerk {
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let callback = try #require(URL(string: "clerk-test://sso-callback"))
    return try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: callback), capabilities: fixture)
  }

  private func awaiting(_ clerk: Clerk, _ owner: AuthFlowRegistration) throws -> AuthFlowWork {
    guard case .awaiting(let work, _) = clerk.authFlowSnapshot(for: owner)?.phase else {
      throw CoreError(code: "expected_awaiting_presentation")
    }
    return work
  }

  @Test func externalActivationWaitsForTheRegisteredRootToDeliverCompletionOnce() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await clerk.signIn.finalize()
    #expect(clerk.session?.status == .active)
    // This must hold even before the view's next reconciliation task runs.
    #expect(!clerk.isAuthFlowComplete)
    clerk.reconcileAuthFlowPresentation()
    let work = try awaiting(clerk, owner)
    #expect(clerk.completeAuthFlow(work))
    #expect(clerk.isAuthFlowComplete)
    #expect(!clerk.completeAuthFlow(work))
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.isAuthFlowComplete)
  }

  @Test func dismissibleExternalActivationLeavesSignedInContentAvailable() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow(role: .dismissible))
    defer { owner.cancel() }
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await clerk.signIn.finalize()
    #expect(clerk.isAuthFlowComplete)
    clerk.reconcileAuthFlowPresentation()
    let work = try awaiting(clerk, owner)
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
  }

  @Test func repeatedCompletionPreservesAnAlreadyPresentedEnrollment() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    let result = TransferFlowResult.signIn(clerk.signIn)
    try await AuthFlowRequestScope.withOwner(owner.id) { try await clerk.finalizeForPresentation(result) }
    let work = try awaiting(clerk, owner)
    let token = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment))
    try await AuthFlowRequestScope.withOwner(owner.id) { try await clerk.finalizeForPresentation(result) }
    #expect(clerk.authFlowPresentationIsCurrent(token))
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.finishAuthFlowPresentation(token))
    #expect(try awaiting(clerk, owner) == work)
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
    #expect(!clerk.finishAuthFlowPresentation(token))
  }

  @Test func sessionTaskScreenKeepsOwnershipAfterTheCoreSessionBecomesActive() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    var session = try #require(fixture.fixtures["session"]).object()
    session["status"] = .string("pending")
    session["tasks"] = .array([.object(["key": .string("setup-mfa")])])
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(session)])
    fixture.clientResponse = .object(client)
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    clerk.reconcileAuthFlowPresentation()
    let work = try awaiting(clerk, owner)
    let token = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks))
    fixture.sessionReloadResponse = try .object(["response": #require(fixture.fixtures["session"]), "client": #require(fixture.fixtures["authenticatedClient"])])
    _ = try await clerk.session?.reload()
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.session?.status == .active)
    #expect(clerk.authFlowPresentationIsCurrent(token))
    #expect(!clerk.completeAuthFlow(work))
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.finishAuthFlowPresentation(token))
    #expect(clerk.completeAuthFlow(work))
    #expect(clerk.isAuthFlowComplete)
  }

  @Test func signOutInvalidatesACompletionWaitingForPresentation() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    let work = try awaiting(clerk, owner)
    try await clerk.signOut()
    #expect(clerk.user == nil)
    #expect(clerk.session == nil)
    #expect(!clerk.completeAuthFlow(work))
    #expect(!clerk.isAuthFlowComplete)
    clerk.reconcileAuthFlowPresentation()
    #expect(!clerk.completeAuthFlow(work))
    #expect(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks) == nil)
  }

  @Test func aRetiredRegistrationCannotFinalizeForItsReplacement() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let previous = try #require(clerk.registerAuthFlow())
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    let result = TransferFlowResult.signIn(clerk.signIn)
    previous.cancel()
    let current = try #require(clerk.registerAuthFlow())
    defer { current.cancel() }
    let requests = fixture.requests.count
    await #expect(throws: CancellationError.self) {
      try await AuthFlowRequestScope.withOwner(previous.id) { try await clerk.finalizeForPresentation(result) }
    }
    #expect(fixture.requests.count == requests)
    #expect(clerk.session == nil)
    #expect(clerk.authFlowRegistrationId == current.id)
    previous.cancel()
    try await AuthFlowRequestScope.withOwner(current.id) { try await clerk.finalizeForPresentation(result) }
    let work = try awaiting(clerk, current)
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
  }
}
#endif
