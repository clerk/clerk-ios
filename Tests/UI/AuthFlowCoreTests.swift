#if os(iOS) || os(macOS)
@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
@testable import NativeCoreProof
import Observation
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

  @Test func anAlreadyActiveSessionDoesNotAcquireARootPresentationGate() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    #expect(!clerk.isAuthFlowComplete)
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await clerk.signIn.finalize()
    #expect(clerk.isAuthFlowComplete)
    #expect(clerk.registerAuthFlow() == nil)
    #expect(clerk.isAuthFlowComplete)
    let sheet = try #require(clerk.registerAuthFlow(role: .dismissible))
    defer { sheet.cancel() }
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.isAuthFlowComplete)
    #expect(try clerk.completeAuthFlow(awaiting(clerk, sheet)))
  }

  @Test func aRejectedSecondRegistrationCannotTakeOverSuspendedFinalization() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    #expect(clerk.registerAuthFlow() == nil)
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    capabilities.pauseNextTouch = true
    let finalization = Task {
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
    }
    await capabilities.waitForPausedTouch()
    #expect(clerk.registerAuthFlow(role: .dismissible) == nil)
    #expect(!clerk.isAuthFlowComplete)
    capabilities.resumeTouch()
    try await finalization.value
    let work = try awaiting(clerk, owner)
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.completeAuthFlow(work))
    #expect(clerk.isAuthFlowComplete)
    #expect(!clerk.completeAuthFlow(work))
  }

  @Test func completingTheRootNotifiesObserversAndAllowsAFreshFlowAfterSignOut() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    let previous = try #require(clerk.registerAuthFlow())
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await AuthFlowRequestScope.withOwner(previous.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    let work = try awaiting(clerk, previous)
    await confirmation("Root content observes presentation completion") { changed in
      withObservationTracking {
        #expect(!clerk.isAuthFlowComplete)
      } onChange: {
        changed()
      }
      #expect(clerk.completeAuthFlow(work))
    }
    #expect(clerk.isAuthFlowComplete)
    previous.cancel()
    #expect(clerk.isAuthFlowComplete)
    try await clerk.signOut()
    #expect(!clerk.isAuthFlowComplete)
    let current = try #require(clerk.registerAuthFlow())
    defer { current.cancel() }
    #expect(!clerk.completeAuthFlow(work))
    // The fixture server must expose the session created by the next SSO callback.
    fixture.signedOut = false
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await AuthFlowRequestScope.withOwner(current.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    let freshWork = try awaiting(clerk, current)
    #expect(freshWork != work)
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.completeAuthFlow(freshWork))
    #expect(clerk.isAuthFlowComplete)
    #expect(!clerk.completeAuthFlow(freshWork))
  }

  @Test(arguments: ["ended", "revoked", "expired"])
  func aTerminalSessionInvalidatesAnOpenEnrollmentScreen(status: String) async throws {
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
    let token = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment))
    var session = try #require(fixture.fixtures["session"]).object()
    session["status"] = .string(status)
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(session)])
    fixture.sessionReloadResponse = .object(["response": .object(session), "client": .object(client)])
    _ = try await clerk.session?.reload()
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    #expect(!clerk.authFlowPresentationIsCurrent(token))
    #expect(!clerk.finishAuthFlowPresentation(token))
    #expect(!clerk.completeAuthFlow(work))
    clerk.reconcileAuthFlowPresentation()
    #expect(!clerk.isAuthFlowComplete)
    #expect(!clerk.finishAuthFlowPresentation(token))
    #expect(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks) == nil)
  }

  @Test func releasingTheRegistrationReleasesTheRootHold() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let clerk = try await connect(fixture)
    defer { clerk.close() }
    var owner = clerk.registerAuthFlow()
    #expect(owner != nil)
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await clerk.signIn.finalize()
    clerk.reconcileAuthFlowPresentation()
    #expect(!clerk.isAuthFlowComplete)
    // No explicit cancellation: AuthView disappearing releases its registration.
    owner = nil
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while clerk.authFlowRegistrationId != nil, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(1))
    }
    #expect(clerk.isAuthFlowComplete)
    let sheet = try #require(clerk.registerAuthFlow(role: .dismissible))
    defer { sheet.cancel() }
    clerk.reconcileAuthFlowPresentation()
    let work = try awaiting(clerk, sheet)
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
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

  @Test func failedRepeatedFinalizationKeepsRecoveredSessionBehindPresentationCompletion() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    try await clerk.signIn.sso(.init(strategy: .oauthGoogle))
    try await clerk.signIn.finalize()
    #expect(clerk.session?.id == "sess_native")
    capabilities.touchStatus = 403
    capabilities.touchResponse = .object(["errors": .array([.object(["code": .string("activation_rejected"), "message": .string("Activation rejected")])])])
    do {
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
      Issue.record("Expected the core finalization error to remain visible")
    } catch let error as CoreError {
      #expect(error.errors.first?.code == "activation_rejected")
    }
    #expect(clerk.session?.id == "sess_native" && clerk.session?.status == .active)
    let work = try awaiting(clerk, owner)
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.completeAuthFlow(work))
    #expect(clerk.isAuthFlowComplete)
    #expect(!clerk.completeAuthFlow(work))
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

  @Test(arguments: [false, true])
  func aNewAuthenticationCompletionReplacesOlderWork(sameSession: Bool) async throws {
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
    let previousFlowId = clerk.signIn.id
    let previousToken: AuthFlowPresentationToken?
    if sameSession {
      previousToken = nil
    } else {
      let token = try #require(clerk.startAuthFlowPresentation(for: owner, work: previous, presentation: .biometricCredentialEnrollment))
      previousToken = token
    }
    let oldSession = try #require(fixture.fixtures["session"])
    var nextSession = try oldSession.object()
    let nextSessionId = sameSession ? "sess_native" : "sess_replacement"
    nextSession["id"] = .string(nextSessionId)
    var nextSignIn = try #require(fixture.fixtures["signIn"]).object()
    nextSignIn["id"] = .string("sia_replacement")
    nextSignIn["status"] = .string("complete")
    nextSignIn["created_session_id"] = .string(nextSessionId)
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array(sameSession ? [oldSession] : [oldSession, .object(nextSession)])
    client["sign_in"] = .object(nextSignIn)
    client["last_active_session_id"] = .string(nextSessionId)
    fixture.clientResponse = .object(client)
    capabilities.signInResponse = .object(["response": .object(nextSignIn), "client": .object(client)])
    capabilities.touchResponse = .object(["response": .object(nextSession), "client": .object(client)])
    try await clerk.signIn.password(.case1(.init(password: "fixture-password", identifier: "new@example.com")))
    #expect(clerk.signIn.id == "sia_replacement")
    #expect(clerk.signIn.id != previousFlowId)
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    #expect(clerk.session?.id == nextSessionId)
    let current = try awaiting(clerk, owner)
    #expect(current != previous)
    #expect(current.sessionId == nextSessionId)
    guard case .awaiting(_, let completion) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The new authentication must own the pending completion")
      return
    }
    #expect(completion?.flowId == "sia_replacement")
    if let previousToken {
      #expect(!clerk.authFlowPresentationIsCurrent(previousToken))
      #expect(!clerk.finishAuthFlowPresentation(previousToken))
    }
    #expect(clerk.startAuthFlowPresentation(for: owner, work: previous, presentation: .biometricCredentialEnrollment) == nil)
    #expect(!clerk.completeAuthFlow(previous))
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.completeAuthFlow(current))
    #expect(!clerk.completeAuthFlow(current))
    #expect(clerk.isAuthFlowComplete)
  }

  @Test func pendingSignUpFinishesEnrollmentBeforeTasksWithoutReofferingIt() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    var session = try #require(fixture.fixtures["session"]).object()
    session["status"] = .string("pending")
    session["tasks"] = .array([.object(["key": .string("setup-mfa")])])
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(session)])
    fixture.clientResponse = .object(client)
    // Completed sign-up responses carry their newly created session in the client envelope.
    let signUp = try #require(client["sign_up"])
    capabilities.signUpResponse = .object(["response": signUp, "client": .object(client)])
    capabilities.touchResponse = .object(["response": .object(session), "client": .object(client)])
    try await clerk.signUp.sso(.init(strategy: "oauth_token_apple"))
    #expect(clerk.signUp.status == .complete)
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signUp(clerk.signUp))
    }
    #expect(clerk.session?.status == .pending)
    let work = try awaiting(clerk, owner)
    guard case .awaiting(_, .signUp(let completion)) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The sign-up must retain its enrollment provenance")
      return
    }
    #expect(completion.id == clerk.signUp.id)
    let enrollment = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment))
    #expect(!clerk.completeAuthFlow(work))
    #expect(clerk.finishAuthFlowPresentation(enrollment))
    guard case .awaiting(let resumed, let offeredEnrollment) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("Completed enrollment must yield to session tasks")
      return
    }
    #expect(resumed == work)
    #expect(offeredEnrollment == nil)
    let tasks = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks))
    #expect(!clerk.isAuthFlowComplete)
    fixture.sessionReloadResponse = try .object(["response": #require(fixture.fixtures["session"]), "client": #require(fixture.fixtures["authenticatedClient"])])
    _ = try await clerk.session?.reload()
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.session?.status == .active)
    #expect(clerk.authFlowPresentationIsCurrent(tasks))
    #expect(clerk.finishAuthFlowPresentation(tasks))
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
  }

  @Test func completionArrivingDuringExternalSessionTasksKeepsTheScreenAndSkipsEnrollment() async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    var session = try #require(fixture.fixtures["session"]).object()
    session["status"] = .string("pending")
    session["tasks"] = .array([.object(["key": .string("setup-mfa")])])
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(session)])
    fixture.clientResponse = .object(client)
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    clerk.reconcileAuthFlowPresentation()
    let work = try awaiting(clerk, owner)
    let tasks = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .sessionTasks))
    var signIn = try #require(fixture.fixtures["signIn"]).object()
    signIn["status"] = .string("complete")
    signIn["created_session_id"] = .string("sess_native")
    client["sign_in"] = .object(signIn)
    fixture.clientResponse = .object(client)
    capabilities.signInResponse = .object(["response": .object(signIn), "client": .object(client)])
    capabilities.touchResponse = .object(["response": .object(session), "client": .object(client)])
    try await clerk.signIn.password(.case1(.init(password: "fixture-password", identifier: "new@example.com")))
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    #expect(clerk.authFlowPresentationIsCurrent(tasks))
    guard case .presenting(let currentToken, .signIn(let completion)) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The existing task screen must receive the completion without replacement")
      return
    }
    #expect(currentToken == tasks)
    #expect(completion.id == clerk.signIn.id)
    #expect(clerk.finishAuthFlowPresentation(tasks))
    guard case .awaiting(let resumed, let enrollment) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The completed task screen must not reopen enrollment")
      return
    }
    #expect(resumed == work)
    #expect(enrollment == nil)
    #expect(!clerk.isAuthFlowComplete)
    fixture.sessionReloadResponse = try .object(["response": #require(fixture.fixtures["session"]), "client": #require(fixture.fixtures["authenticatedClient"])])
    _ = try await clerk.session?.reload()
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
  }

  @Test(arguments: [false, true], [false, true])
  func activationAdoptsItsTargetOrRecoversCurrentSessionAfterAnIntermediateRefresh(dismissible: Bool, succeeds: Bool) async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let targetSession = try #require(fixture.fixtures["session"])
    var currentSession = try targetSession.object()
    currentSession["id"] = .string("sess_existing")
    if !dismissible {
      currentSession["status"] = .string("pending")
      currentSession["tasks"] = .array([.object(["key": .string("setup-mfa")])])
    }
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(currentSession), targetSession])
    client["last_active_session_id"] = .string("sess_existing")
    fixture.clientResponse = .object(client)
    let capabilities = AuthFlowCapabilities(base: fixture)
    capabilities.responseDate = "Mon, 31 Dec 2029 00:00:00 GMT"
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    #expect(clerk.session?.id == "sess_existing")
    let owner = try #require(clerk.registerAuthFlow(role: dismissible ? .dismissible : .root))
    defer { owner.cancel() }
    capabilities.pauseNextTouch = true
    capabilities.touchHeaders = ["date": .string("Tue, 01 Jan 2030 00:00:00 GMT")]
    capabilities.touchStatus = succeeds ? 200 : 403
    var successfulClient = client
    var refreshedCurrentSession = currentSession
    refreshedCurrentSession["status"] = .string("active")
    refreshedCurrentSession["tasks"] = .array([])
    successfulClient["sessions"] = .array([.object(refreshedCurrentSession), targetSession])
    successfulClient["last_active_session_id"] = .string("sess_native")
    capabilities.touchResponse = succeeds
      ? .object(["response": targetSession, "client": .object(successfulClient)])
      : .object(["errors": .array([.object(["code": .string("activation_rejected"), "message": .string("Activation rejected")])])])
    let finalization = Task {
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
    }
    await capabilities.waitForPausedTouch()
    defer { capabilities.resumeTouch() }
    let pending = try awaiting(clerk, owner)
    #expect(pending.sessionId == "sess_native")
    #expect(clerk.startAuthFlowPresentation(for: owner, work: pending, presentation: .biometricCredentialEnrollment) == nil)
    #expect(!clerk.completeAuthFlow(pending))
    currentSession["status"] = .string("active")
    currentSession["tasks"] = .array([])
    client["sessions"] = .array([.object(currentSession), targetSession])
    fixture.sessionReloadResponse = .object(["response": targetSession, "client": .object(client)])
    _ = try await #require(clerk.sessions.first { $0.id == "sess_native" }).reload()
    #expect(clerk.session?.id == "sess_existing")
    #expect(clerk.session?.status == .active)
    clerk.reconcileAuthFlowPresentation()
    #expect(try awaiting(clerk, owner) == pending)
    #expect(clerk.isAuthFlowComplete == dismissible)
    capabilities.resumeTouch()
    if succeeds {
      try await finalization.value
    } else {
      do {
        try await finalization.value
        Issue.record("Expected the activation error to reach the caller")
      } catch let error as CoreError {
        #expect(error.errors.first?.code == "activation_rejected")
      }
    }
    let completed = try awaiting(clerk, owner)
    #expect(completed.sessionId == (succeeds ? "sess_native" : "sess_existing"))
    #expect((completed == pending) == succeeds)
    guard case .awaiting(_, let completion) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The final selected session must supply presentation work")
      return
    }
    #expect((completion != nil) == succeeds)
    if !succeeds { #expect(!clerk.completeAuthFlow(pending)) }
    #expect(clerk.isAuthFlowComplete == dismissible)
    #expect(clerk.completeAuthFlow(completed))
    #expect(!clerk.completeAuthFlow(completed))
    #expect(clerk.isAuthFlowComplete)
  }

  @Test(arguments: [false, true])
  func activationWorkSurvivesRefreshOrRecoversFromAnObsoleteReply(comparableDates: Bool) async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let capabilities = AuthFlowCapabilities(base: fixture)
    if comparableDates { capabilities.responseDate = "Mon, 31 Dec 2029 00:00:00 GMT" }
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow())
    defer { owner.cancel() }
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["last_active_session_id"] = .null
    let session = try #require(fixture.fixtures["session"])
    let signIn = try #require(client["sign_in"])
    capabilities.signInResponse = .object(["response": signIn, "client": .object(client)])
    try await clerk.signIn.password(.case1(.init(password: "fixture-password", identifier: "new@example.com")))
    #expect(clerk.session == nil)
    capabilities.pauseNextTouch = true
    capabilities.touchResponse = .object(["response": session, "client": .object(client)])
    // Its later date proves freshness only when the intervening refresh has a comparable date.
    capabilities.touchHeaders = ["date": .string("Tue, 01 Jan 2030 00:00:00 GMT")]
    let finalization = Task {
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
    }
    await capabilities.waitForPausedTouch()
    defer { capabilities.resumeTouch() }
    let work = try awaiting(clerk, owner)
    fixture.sessionReloadResponse = .object(["response": session, "client": .object(client)])
    _ = try await #require(clerk.sessions.first { $0.id == "sess_native" }).reload()
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.session == nil)
    #expect(try awaiting(clerk, owner) == work)
    #expect(!clerk.completeAuthFlow(work))
    #expect(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment) == nil)
    capabilities.resumeTouch()
    if comparableDates {
      try await finalization.value
      #expect(try awaiting(clerk, owner) == work)
    } else {
      do {
        try await finalization.value
        Issue.record("An older reply cannot prove freshness without comparable server dates")
      } catch let error as CoreError {
        #expect(error.code == "stale_client_response")
      }
      #expect(clerk.session == nil)
      #expect(!clerk.completeAuthFlow(work))
      // A fresh explicit attempt must recover after the rejected reply.
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
      #expect(try awaiting(clerk, owner) != work)
      #expect(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment) == nil)
    }
    #expect(clerk.session?.id == "sess_native")
    let completedWork = try awaiting(clerk, owner)
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.completeAuthFlow(completedWork))
    #expect(!clerk.completeAuthFlow(completedWork))
  }

  @Test func aRejectedReplayPreservesAcceptedAwaitingWork() async throws {
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
    let work = try awaiting(clerk, owner)
    capabilities.touchStatus = 403
    capabilities.touchResponse = .object(["errors": .array([.object(["code": .string("activation_rejected"), "message": .string("Activation rejected")])])])
    do {
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
      Issue.record("Expected a repeated activation error")
    } catch let error as CoreError {
      #expect(error.errors.first?.code == "activation_rejected")
    }
    #expect(try awaiting(clerk, owner) == work)
    #expect(clerk.session?.id == work.sessionId)
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
  }

  @Test(arguments: [false, true])
  func aNewerExplicitSelectionSupersedesSuspendedFinalization(dismissible: Bool) async throws {
    let fixture = try FixtureCapabilities(data: PackageProof.fixtureData())
    let targetSession = try #require(fixture.fixtures["session"])
    var currentSession = try targetSession.object()
    currentSession["id"] = .string("sess_existing")
    if !dismissible {
      currentSession["status"] = .string("pending")
      currentSession["tasks"] = .array([.object(["key": .string("setup-mfa")])])
    }
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    client["sessions"] = .array([.object(currentSession), targetSession])
    client["last_active_session_id"] = .string("sess_existing")
    fixture.clientResponse = .object(client)
    let capabilities = AuthFlowCapabilities(base: fixture)
    let clerk = try await connect(capabilities)
    defer { clerk.close() }
    let owner = try #require(clerk.registerAuthFlow(role: dismissible ? .dismissible : .root))
    defer { owner.cancel() }
    var delayedClient = client
    delayedClient["last_active_session_id"] = .string("sess_native")
    capabilities.touchResponses["/v1/client/sessions/sess_native/touch"] = .object(["response": targetSession, "client": .object(delayedClient)])
    capabilities.pauseNextTouch = true
    let finalization = Task {
      try await AuthFlowRequestScope.withOwner(owner.id) {
        try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
      }
    }
    await capabilities.waitForPausedTouch()
    defer { capabilities.resumeTouch() }
    let superseded = try awaiting(clerk, owner)
    #expect(superseded.sessionId == "sess_native")
    currentSession["status"] = .string("active")
    currentSession["tasks"] = .array([])
    client["sessions"] = .array([.object(currentSession), targetSession])
    capabilities.touchResponses["/v1/client/sessions/sess_existing/touch"] = .object(["response": .object(currentSession), "client": .object(client)])
    try await clerk.setActive(.init(session: .value(.case1("sess_existing"))))
    #expect(clerk.session?.id == "sess_existing")
    #expect(clerk.session?.status == .active)
    #expect(!clerk.completeAuthFlow(superseded))
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.isAuthFlowComplete == dismissible)
    capabilities.resumeTouch()
    do {
      try await finalization.value
      Issue.record("The superseded activation must not report success")
    } catch {}
    #expect(clerk.session?.id == "sess_existing")
    #expect(clerk.sessions.contains { $0.id == "sess_native" })
    let current = try awaiting(clerk, owner)
    #expect(current.sessionId == "sess_existing")
    #expect(current != superseded)
    guard case .awaiting(_, let completion) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The newer selection must supply external presentation work")
      return
    }
    #expect(completion == nil)
    #expect(clerk.startAuthFlowPresentation(for: owner, work: superseded, presentation: .biometricCredentialEnrollment) == nil)
    #expect(clerk.completeAuthFlow(current))
    #expect(!clerk.completeAuthFlow(current))
  }

  @Test func anOpenEnrollmentSurvivesRefreshAndALaterAttemptWithoutBeingReoffered() async throws {
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
    let work = try awaiting(clerk, owner)
    let firstAttemptId = clerk.signIn.id
    let enrollment = try #require(clerk.startAuthFlowPresentation(for: owner, work: work, presentation: .biometricCredentialEnrollment))
    fixture.sessionReloadResponse = try .object(["response": #require(fixture.fixtures["session"]), "client": #require(fixture.fixtures["authenticatedClient"])])
    _ = try await clerk.session?.reload()
    clerk.reconcileAuthFlowPresentation()
    #expect(clerk.authFlowPresentationIsCurrent(enrollment))
    var client = try #require(fixture.fixtures["authenticatedClient"]).object()
    var signIn = try #require(client["sign_in"]).object()
    signIn["id"] = .string("sia_later")
    client["sign_in"] = .object(signIn)
    capabilities.signInResponse = .object(["response": .object(signIn), "client": .object(client)])
    capabilities.touchResponse = try .object(["response": #require(fixture.fixtures["session"]), "client": .object(client)])
    try await clerk.signIn.password(.case1(.init(password: "fixture-password", identifier: "new@example.com")))
    #expect(clerk.signIn.id != firstAttemptId)
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    #expect(clerk.authFlowPresentationIsCurrent(enrollment))
    #expect(!clerk.isAuthFlowComplete)
    #expect(clerk.finishAuthFlowPresentation(enrollment))
    #expect(try awaiting(clerk, owner) == work)
    // Replaying the later accepted attempt must not reopen the completed enrollment.
    try await AuthFlowRequestScope.withOwner(owner.id) {
      try await clerk.finalizeForPresentation(.signIn(clerk.signIn))
    }
    guard case .awaiting(let resumed, let offeredEnrollment) = clerk.authFlowSnapshot(for: owner)?.phase else {
      Issue.record("The completed screen must resume its existing work")
      return
    }
    #expect(resumed == work)
    #expect(offeredEnrollment == nil)
    #expect(!clerk.finishAuthFlowPresentation(enrollment))
    #expect(clerk.completeAuthFlow(work))
    #expect(!clerk.completeAuthFlow(work))
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

  var signInResponse: JSONValue?
  var signUpResponse: JSONValue?
  var touchResponse: JSONValue?
  var touchResponses: [String: JSONValue] = [:]
  var touchStatus = 200
  var touchHeaders: [String: JSONValue] = [:]
  var responseDate: String?
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
    if capability == "http", let path = try arguments.object()["url"]?.url().path {
      let response = path.contains("/sign_ins") ? signInResponse : path.contains("/sign_ups") ? signUpResponse : nil
      if let response {
        return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(response), as: UTF8.self))])
      }
    }
    if capability == "http", let path = try arguments.object()["url"]?.url().path, path.hasSuffix("/touch") {
      let response = touchResponses[path] ?? touchResponse
      if pauseNextTouch {
        pauseNextTouch = false
        await withCheckedContinuation { continuation in
          pausedTouch = continuation
          let observer = touchObserver
          touchObserver = nil
          observer?.resume()
        }
      }
      if let response {
        return try .object(["status": .number(Double(touchStatus)), "headers": .object(touchHeaders), "body": .string(String(decoding: JSONEncoder().encode(response), as: UTF8.self))])
      }
    }
    let response = try await base.perform(capability, arguments: arguments)
    if capability == "http", let responseDate {
      var envelope = try response.object()
      var headers = try (envelope["headers"] ?? .object([:])).object()
      headers["date"] = .string(responseDate)
      envelope["headers"] = .object(headers)
      return .object(envelope)
    }
    return response
  }
}
#endif
