#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct ReverifierTests {
  @Test
  func skipsTheSheetWhenTheUserVerifiedRecently() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = Reverifier(isSatisfied: { _ in true }) { presentedLevels.append($0) }

    try await reverify(.strict)

    #expect(presentedLevels.isEmpty)
  }

  @Test
  func presentsTheLevelTheRequirementNeeds() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = Reverifier(isSatisfied: { _ in false }) { presentedLevels.append($0) }

    try await reverify(.strictMfa)
    try await reverify(.custom(level: .firstFactor, afterMinutes: 5))

    #expect(presentedLevels == [.multiFactor, .firstFactor])
  }

  @Test
  func retriesTheOperationOnceAfterReverifying() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    var attempts = 0
    let reverify = Reverifier(isSatisfied: { _ in false }) { presentedLevels.append($0) }

    let value = try await reverify {
      attempts += 1
      if attempts == 1 {
        throw ReverificationRequiredError(reverification: .custom(level: .firstFactor, afterMinutes: 10))
      }
      return "done"
    }

    #expect(value == "done")
    #expect(attempts == 2)
    #expect(presentedLevels == [.firstFactor])
  }

  @Test
  func clerksReverificationErrorAsksForASecondFactor() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    var attempts = 0
    let reverify = Reverifier(isSatisfied: { _ in false }) { presentedLevels.append($0) }

    try await reverify {
      attempts += 1
      if attempts == 1 {
        throw ClerkAPIError(code: "session_reverification_required")
      }
    }

    #expect(presentedLevels == [.secondFactor])
  }

  @Test
  func otherErrorsPassThroughWithoutTheSheet() async {
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = Reverifier(isSatisfied: { _ in false }) { presentedLevels.append($0) }

    await #expect(throws: ClerkAPIError.self) {
      try await reverify {
        throw ClerkAPIError(code: "form_param_missing")
      }
    }
    #expect(presentedLevels.isEmpty)
  }

  @Test
  func cancellingTheSheetDoesNotRetry() async {
    var attempts = 0
    let reverify = Reverifier(isSatisfied: { _ in false }) { _ in
      throw ReverificationCancelledError()
    }

    await #expect(throws: ReverificationCancelledError.self) {
      try await reverify {
        attempts += 1
        throw ReverificationRequiredError()
      }
    }
    #expect(attempts == 1)
  }

  // MARK: - Presenter

  @Test(arguments: [
    (true, ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_b")),
    (false, ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_b")),
    (true, ClerkSignedInIdentity(clientId: "client_b", sessionId: "sess_a")),
    (false, ClerkSignedInIdentity(clientId: "client_b", sessionId: "sess_a")),
  ])
  func anIdentityChangeBeforeTheRetryCancelsIt(changesBeforeTheSheet: Bool, changed: ClerkSignedInIdentity) async {
    var identity = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_a")
    var attempts = 0
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = Reverifier(isSatisfied: { _ in false }, currentIdentity: { identity }) {
      presentedLevels.append($0)
      identity = changed
    }

    await #expect(throws: ReverificationCancelledError.self) {
      try await reverify {
        attempts += 1
        if changesBeforeTheSheet {
          identity = changed
        }
        throw ReverificationRequiredError(reverification: .strict)
      }
    }
    #expect(attempts == 1)
    #expect(presentedLevels.count == (changesBeforeTheSheet ? 0 : 1))
  }

  @Test
  func theStoredIdentityIsCheckedOnlyAfterTheFirstAttemptFails() async throws {
    let identity = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_a")
    var events: [String] = []
    let reverify = Reverifier(
      isSatisfied: { _ in false },
      startingIdentity: {
        events.append("starting")
        return identity
      },
      currentIdentity: {
        events.append("current")
        return identity
      }
    ) { _ in events.append("present") }

    var attempts = 0
    try await reverify {
      attempts += 1
      events.append("attempt")
      if attempts == 1 {
        throw ReverificationRequiredError(reverification: .strict)
      }
    }

    #expect(events == ["starting", "attempt", "current", "present", "current", "attempt"])
  }

  @Test
  func aRequirementCheckWhoseIdentityChangedDuringTheSheetCancels() async {
    var identity = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_a")
    let reverify = Reverifier(isSatisfied: { _ in false }, currentIdentity: { identity }) { _ in
      identity = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_b")
    }

    await #expect(throws: ReverificationCancelledError.self) {
      try await reverify(.strict)
    }
  }

  @Test
  func aRequirementClerkDoesNotSupportThrowsWithoutPresenting() async {
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = Reverifier(isSatisfied: { _ in false }) { presentedLevels.append($0) }

    await #expect(throws: ReverificationUnsupportedRequirementError.self) {
      try await reverify(.custom(level: .multiFactor, afterMinutes: 0))
    }
    #expect(presentedLevels.isEmpty)
  }

  @Test
  func aCallerCancelledWhileTheSheetIsUpDoesNotRunTheOperationAgain() async {
    var attempts = 0
    let reverify = Reverifier(isSatisfied: { _ in false }) { _ in
      withUnsafeCurrentTask { $0?.cancel() }
    }

    let task = Task {
      try await reverify {
        attempts += 1
        if attempts == 1 {
          throw ReverificationRequiredError(reverification: .strict)
        }
      }
    }

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    #expect(attempts == 1)
  }

  @Test
  func everyCallerAtTheSameLevelSharesOneSheet() async throws {
    let display = RecordingSheetDisplay()
    let presenter = ReverificationPresenter(display: display)
    async let first: Void = presenter.present(level: .secondFactor, clerk: .mock)
    async let second: Void = presenter.present(level: .secondFactor, clerk: .mock)
    try await waitUntil { !display.shown.isEmpty }
    for _ in 0 ..< 10 {
      await Task.yield()
    }
    #expect(display.shown.count == 1)
    #expect(display.shown.first?.request.level == .secondFactor)

    display.complete(0)

    try await first
    try await second
  }

  @Test
  func aCallForAnotherIdentityAtTheSameLevelGetsItsOwnSheet() async throws {
    let display = RecordingSheetDisplay()
    let presenter = ReverificationPresenter(display: display)
    let first = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_a")
    let second = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_b")

    let firstTask = Task { try await presenter.present(level: .firstFactor, clerk: .mock, identity: first) }
    try await waitUntil { display.shown.count == 1 }
    let secondTask = Task { try await presenter.present(level: .firstFactor, clerk: .mock, identity: second) }
    for _ in 0 ..< 10 {
      await Task.yield()
    }

    #expect(display.shown.count == 1)
    display.complete(0)
    try await firstTask.value
    try await waitUntil { display.shown.count == 2 }

    #expect(display.shown.last?.request.identity == second)
    display.complete(1)
    try await secondTask.value
  }

  @Test
  func aCallAtAnotherLevelWaitsForTheSheetPresentedFirst() async throws {
    let display = RecordingSheetDisplay()
    let presenter = ReverificationPresenter(display: display)

    let first = Task { try await presenter.present(level: .firstFactor, clerk: .mock) }
    try await waitUntil { display.shown.count == 1 }
    let second = Task { try await presenter.present(level: .multiFactor, clerk: .mock) }
    for _ in 0 ..< 10 {
      await Task.yield()
    }

    #expect(display.shown.count == 1)
    #expect(display.shown.first?.request.level == .firstFactor)
    display.complete(0)
    try await first.value
    try await waitUntil { display.shown.count == 2 }

    #expect(display.shown.last?.request.level == .multiFactor)
    display.complete(1)
    try await second.value
  }

  @Test
  func aCallerCancelledWhileWaitingForAnotherLevelDoesNotPresent() async throws {
    let display = RecordingSheetDisplay()
    let presenter = ReverificationPresenter(display: display)

    let first = Task { try await presenter.present(level: .firstFactor, clerk: .mock) }
    try await waitUntil { display.shown.count == 1 }
    let second = Task { try await presenter.present(level: .multiFactor, clerk: .mock) }
    for _ in 0 ..< 10 {
      await Task.yield()
    }
    second.cancel()
    display.complete(0)
    try await first.value

    await #expect(throws: CancellationError.self) {
      try await second.value
    }
    #expect(display.shown.count == 1)
  }

  @Test
  func aCancelledCallerDoesNotPresentButALiveCallerThatJoinedGetsItsOwnSheet() async throws {
    let display = GatedSheetDisplay()
    let presenter = ReverificationPresenter(display: display)

    let cancelled = Task { try await presenter.present(level: .firstFactor, clerk: .mock) }
    try await waitUntil { display.heldShows == 1 }
    let joined = Task { try await presenter.present(level: .firstFactor, clerk: .mock) }
    for _ in 0 ..< 10 {
      await Task.yield()
    }
    cancelled.cancel()
    display.releaseHeldShows()

    await #expect(throws: CancellationError.self) {
      try await cancelled.value
    }
    try await waitUntil { display.heldShows == 1 }
    display.releaseHeldShows()
    try await waitUntil { display.shown.count == 1 }
    display.complete(0)
    try await joined.value
  }

  @Test
  func aCancelledCallerDoesNotPresentForCallersWaitingOnAnotherLevelOrCancelledThemselves() async throws {
    let display = GatedSheetDisplay()
    let presenter = ReverificationPresenter(display: display)

    let cancelled = Task { try await presenter.present(level: .firstFactor, clerk: .mock) }
    try await waitUntil { display.heldShows == 1 }
    let cancelledJoiner = Task { try await presenter.present(level: .firstFactor, clerk: .mock) }
    let otherLevel = Task { try await presenter.present(level: .multiFactor, clerk: .mock) }
    for _ in 0 ..< 10 {
      await Task.yield()
    }
    cancelledJoiner.cancel()
    cancelled.cancel()
    display.releaseHeldShows()

    await #expect(throws: CancellationError.self) {
      try await cancelled.value
    }
    await #expect(throws: CancellationError.self) {
      try await cancelledJoiner.value
    }
    try await waitUntil { display.heldShows == 1 }
    display.releaseHeldShows()
    try await waitUntil { display.shown.count == 1 }

    #expect(display.shown.first?.request.level == .multiFactor)
    display.complete(0)
    try await otherLevel.value
  }

  @Test
  func aSheetThatVerifiedAnotherSessionAfterTheIdentityChangedDuringPresentationCancelsTheCaller() async throws {
    let display = GatedSheetDisplay()
    let presenter = ReverificationPresenter(display: display)
    let identity = ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_a")

    let caller = Task { try await presenter.present(level: .firstFactor, clerk: .mock, identity: identity) }
    try await waitUntil { display.heldShows == 1 }
    display.releaseHeldShows()
    try await waitUntil { display.shown.count == 1 }
    display.complete(0, verifiedSessionId: "sess_b")

    await #expect(throws: ReverificationCancelledError.self) {
      try await caller.value
    }
  }

  @Test
  func dismissingTheSheetBeforeItCompletesCancels() async throws {
    let display = RecordingSheetDisplay()
    let presenter = ReverificationPresenter(display: display)

    let task = Task { try await presenter.present(level: .secondFactor, clerk: .mock) }
    try await waitUntil { !display.shown.isEmpty }
    display.shown[0].onDismiss()

    await #expect(throws: ReverificationCancelledError.self) {
      try await task.value
    }
  }

  @Test
  func aSheetThatCannotBePresentedThrowsAndTheNextCallPresentsAgain() async throws {
    let display = RecordingSheetDisplay()
    display.hasWindow = false
    let presenter = ReverificationPresenter(display: display)

    await #expect(throws: ReverificationNotPresentedError.self) {
      try await presenter.present(level: .secondFactor, clerk: .mock)
    }

    display.hasWindow = true
    let task = Task { try await presenter.present(level: .secondFactor, clerk: .mock) }
    try await waitUntil { !display.shown.isEmpty }
    display.complete(0)
    try await task.value
  }

  @Test
  func aSheetThatVerifiedAnotherSessionDoesNotCompleteTheRequest() async {
    let request = ReverificationRequest(
      level: .firstFactor,
      identity: ClerkSignedInIdentity(clientId: "client_a", sessionId: "sess_a")
    )
    request.markComplete(verifiedSessionId: "sess_b")
    request.finish()

    await #expect(throws: ReverificationCancelledError.self) {
      try await request.wait()
    }
  }

  @Test
  func aSheetThatClosedBeforeTheCallerWaitedStillReturns() async throws {
    let request = ReverificationRequest(level: .firstFactor)
    request.markComplete(verifiedSessionId: nil)
    request.finish()

    try await request.wait()
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 100 where !condition() {
      await Task.yield()
    }
    try #require(condition())
  }
}

@MainActor
private final class RecordingSheetDisplay: ReverificationSheetDisplay {
  struct Shown {
    let request: ReverificationRequest
    let onDismiss: @MainActor () -> Void
  }

  var hasWindow = true
  private(set) var shown: [Shown] = []

  func show(
    _ request: ReverificationRequest,
    clerk _: Clerk,
    onDismiss: @escaping @MainActor () -> Void
  ) async -> Bool {
    guard hasWindow else { return false }
    shown.append(Shown(request: request, onDismiss: onDismiss))
    return true
  }

  func complete(_ index: Int) {
    shown[index].request.markComplete(verifiedSessionId: shown[index].request.identity?.sessionId)
    shown[index].onDismiss()
  }
}

@MainActor
private final class GatedSheetDisplay: ReverificationSheetDisplay {
  struct Shown {
    let request: ReverificationRequest
    let onDismiss: @MainActor () -> Void
  }

  private(set) var shown: [Shown] = []
  private var held: [CheckedContinuation<Void, Never>] = []

  var heldShows: Int {
    held.count
  }

  func show(
    _ request: ReverificationRequest,
    clerk _: Clerk,
    onDismiss: @escaping @MainActor () -> Void
  ) async -> Bool {
    await withCheckedContinuation { held.append($0) }
    guard !Task.isCancelled else { return false }
    shown.append(Shown(request: request, onDismiss: onDismiss))
    return true
  }

  func releaseHeldShows() {
    let released = held
    held = []
    released.forEach { $0.resume() }
  }

  func complete(_ index: Int, verifiedSessionId: String? = nil) {
    let request = shown[index].request
    request.markComplete(verifiedSessionId: verifiedSessionId ?? request.identity?.sessionId)
    shown[index].onDismiss()
  }
}

#endif
