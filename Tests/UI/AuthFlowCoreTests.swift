#if os(iOS) || os(macOS)
@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
@testable import NativeCoreProof
import Testing

@MainActor @Suite(.serialized) struct AuthFlowCoreTests {
  private func connect(_ fixture: any NativeCapabilities) async throws -> Clerk {
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

  @Test func replayAfterEnrollmentFinishesDoesNotOfferEnrollmentAgain() async throws {
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
    #expect(clerk.finishAuthFlowPresentation(token))
    try await AuthFlowRequestScope.withOwner(owner.id) { try await clerk.finalizeForPresentation(result) }
    guard case .awaiting(let replayedWork, let enrollment) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("Expected the completed enrollment to resume its original work")
      return
    }
    #expect(replayedWork == work)
    #expect(enrollment == nil)
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
  }

  @Test func anotherCurrentSessionInvalidatesThePresentedScreen() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    let previous = try awaiting(clerk, owner)
    let token = try #require(clerk.startAuthFlowPresentation(for: owner, work: previous, presentation: .biometricCredentialEnrollment))
    let oldSession = try #require(fixture.fixtures["session"])
    var replacement = try oldSession.object()
    replacement["id"] = .string("sess_replacement")
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([oldSession, .object(replacement)])
    client["last_active_session_id"] = .string("sess_replacement")
    fixture.sessionReloadResponse = .object(["response": oldSession, "client": .object(client)])
    _ = try await clerk.session?.reload()
    #expect(clerk.session?.id == "sess_native")
    capabilities.touchResponse = .object(["response": .object(replacement), "client": .object(client)])
    try await clerk.setActive(.init(session: .value(.case1("sess_replacement"))))
    #expect(clerk.session?.id == "sess_replacement")
    #expect(!clerk.authFlowPresentationIsCurrent(token))
    #expect(!clerk.finishAuthFlowPresentation(token))
    #expect(!clerk.completeAuthFlow(previous))
    clerk.reconcileAuthFlowPresentation()
    let current = try awaiting(clerk, owner)
    #expect(current.sessionId == "sess_replacement")
    #expect(current != previous)
    #expect(clerk.completeAuthFlow(current))
    #expect(!clerk.completeAuthFlow(current))
  }

  @Test func aNewSessionTaskWaitsForEnrollmentToFinish() async throws {
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
    let enrollmentToken = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment))
    var session = try #require(fixture.fixtures["session"]).object()
    session["status"] = .string("pending")
    session["tasks"] = .array([.object(["key": .string("setup-mfa")])])
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(session)])
    fixture.sessionReloadResponse = .object(["response": .object(session), "client": .object(client)])
    _ = try await clerk.session?.reload()
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.session?.status == .pending)
    #expect(clerk.authFlowPresentationIsCurrent(enrollmentToken))
    #expect(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks) == nil)
    #expect(clerk.finishAuthFlowPresentation(enrollmentToken))
    guard case .awaiting(let resumed, let enrollment) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("Expected enrollment to yield to the pending session task")
      return
    }
    #expect(resumed == work)
    #expect(enrollment == nil)
    #expect(!clerk.completeAuthFlow(work))
    let taskToken = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks))
    fixture.sessionReloadResponse = try .object(["response": #require(fixture.fixtures["session"]), "client": #require(fixture.fixtures["authenticatedClient"])])
    _ = try await clerk.session?.reload()
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.authFlowPresentationIsCurrent(taskToken))
    #expect(clerk.finishAuthFlowPresentation(taskToken))
    #expect(clerk.completeAuthFlow(work))
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

  @Test func cancellingAnOwnerDuringFinalizationRejectsItsLateResponse() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let previous = try #require(clerk.registerAuthFlow())
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    let result = TransferFlowResult.signIn(clerk.signIn)
    capabilities.pauseNextTouch = true
    let finalization = Task {
      try await AuthFlowRequestScope.withOwner(previous.id) {
        try await clerk.finalizeForPresentation(result)
      }
    }
    await capabilities.waitForPausedTouch()
    previous.cancel()
    let current = try #require(clerk.registerAuthFlow())
    defer { current.cancel() }
    capabilities.resumeTouch()
    await #expect(throws: CancellationError.self) { try await finalization.value }
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    #expect(clerk.authFlowRegistrationId == current.id)
    clerk.reconcileAuthFlowPresentation()
    #expect(!clerk.isAuthFlowComplete)
    guard case .observing = clerk.authFlowSnapshot(for: current)?.phase else {
      Issue.record("A late response must not create work for the replacement owner")
      return
    }
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

@MainActor private final class AuthFlowCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var touchResponse: JSONValue?
  var pauseNextTouch = false
  private var pausedTouch: CheckedContinuation<Void, Never>?
  private var touchObserver: CheckedContinuation<Void, Never>?

  init(base: FixtureCapabilities) {
    self.base = base
  }

  func waitForPausedTouch() async {
    if pausedTouch != nil { return }
    await withCheckedContinuation { touchObserver = $0 }
  }

  func resumeTouch() {
    let continuation = pausedTouch
    pausedTouch = nil
    continuation?.resume()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    if capability == "http", try arguments.object()["url"]?.url().path.hasSuffix("/touch") == true {
      if pauseNextTouch {
        pauseNextTouch = false
        await withCheckedContinuation { continuation in
          pausedTouch = continuation
          let observer = touchObserver
          touchObserver = nil
          observer?.resume()
        }
      }
      if let touchResponse {
        return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(touchResponse), as: UTF8.self))])
      }
    }
    return try await base.perform(capability, arguments: arguments)
  }
}
#endif
