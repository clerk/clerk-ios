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
    (true, ClerkSignedInIdentity(sessionId: "sess_b", deviceToken: "device_a")),
    (false, ClerkSignedInIdentity(sessionId: "sess_b", deviceToken: "device_a")),
    (true, ClerkSignedInIdentity(sessionId: "sess_a", deviceToken: "device_b")),
    (false, ClerkSignedInIdentity(sessionId: "sess_a", deviceToken: "device_b")),
  ])
  func anIdentityChangeBeforeTheRetryCancelsIt(changesBeforeTheSheet: Bool, changed: ClerkSignedInIdentity) async {
    var identity = ClerkSignedInIdentity(sessionId: "sess_a", deviceToken: "device_a")
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
  func aSheetThatClosedBeforeTheCallerWaitedStillReturns() async throws {
    let request = ReverificationRequest(level: .firstFactor)
    request.markComplete()
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
    shown[index].request.markComplete()
    shown[index].onDismiss()
  }
}

#endif
