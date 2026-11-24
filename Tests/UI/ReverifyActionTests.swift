#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct ReverifyActionTests {
  @Test
  func skipsTheSheetWhenTheUserVerifiedRecently() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = ReverifyAction(isSatisfied: { _ in true }) { presentedLevels.append($0) }

    try await reverify(.strict)

    #expect(presentedLevels.isEmpty)
  }

  @Test
  func presentsTheLevelTheRequirementNeeds() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    let reverify = ReverifyAction(isSatisfied: { _ in false }) { presentedLevels.append($0) }

    try await reverify(.strictMfa)
    try await reverify(.custom(level: .firstFactor, afterMinutes: 5))

    #expect(presentedLevels == [.multiFactor, .firstFactor])
  }

  @Test
  func retriesTheOperationOnceAfterReverifying() async throws {
    var presentedLevels: [SessionVerification.Level] = []
    var attempts = 0
    let reverify = ReverifyAction(isSatisfied: { _ in false }) { presentedLevels.append($0) }

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
    let reverify = ReverifyAction(isSatisfied: { _ in false }) { presentedLevels.append($0) }

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
    let reverify = ReverifyAction(isSatisfied: { _ in false }) { presentedLevels.append($0) }

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
    let reverify = ReverifyAction(isSatisfied: { _ in false }) { _ in
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

  @Test
  func withoutAHostReverifyThrows() async {
    await #expect(throws: ReverificationHostMissingError.self) {
      try await ReverifyAction.missingHost(.strict)
    }
  }

  // MARK: - Presenter

  @Test
  func everyCallerAtTheSameLevelSharesOneSheet() async throws {
    let presenter = ReverificationPresenter()
    async let first: Void = presenter.present(level: .secondFactor)
    async let second: Void = presenter.present(level: .secondFactor)
    try await waitUntil { presenter.presented != nil }
    let sheet = try #require(presenter.presented)
    for _ in 0 ..< 10 {
      await Task.yield()
    }
    #expect(presenter.presented === sheet)

    #expect(presenter.presented?.level == .secondFactor)
    presenter.presented?.markComplete()
    presenter.presented = nil
    presenter.sheetDidDismiss()

    try await first
    try await second
    #expect(presenter.presented == nil)
  }

  @Test
  func aCallAtAnotherLevelWaitsForTheSheetPresentedFirst() async throws {
    let presenter = ReverificationPresenter()

    let first = Task { try await presenter.present(level: .firstFactor) }
    await Task.yield()
    let second = Task { try await presenter.present(level: .multiFactor) }
    await Task.yield()

    #expect(presenter.presented?.level == .firstFactor)
    presenter.presented?.markComplete()
    presenter.presented = nil
    presenter.sheetDidDismiss()
    try await first.value
    try await waitUntil { presenter.presented != nil }

    #expect(presenter.presented?.level == .multiFactor)
    presenter.presented?.markComplete()
    presenter.presented = nil
    presenter.sheetDidDismiss()
    try await second.value
  }

  @Test
  func dismissingTheSheetBeforeItCompletesCancels() async {
    let presenter = ReverificationPresenter()

    let task = Task { try await presenter.present(level: .secondFactor) }
    await Task.yield()
    presenter.presented = nil
    presenter.sheetDidDismiss()

    await #expect(throws: ReverificationCancelledError.self) {
      try await task.value
    }
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 100 where !condition() {
      await Task.yield()
    }
    try #require(condition())
  }
}

#endif
