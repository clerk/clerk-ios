#if os(iOS) || os(macOS)

@testable import ClerkKitUI
import Testing

struct OTPSubmissionTrackerTests {
  @Test
  func reappearingTaskDoesNotClaimSameCompleteCode() {
    var tracker = OTPSubmissionTracker()

    #expect(tracker.claimCode("123456", requiredLength: 6) == "123456")
    #expect(tracker.claimCode("123456", requiredLength: 6) == nil)
  }

  @Test
  func incompleteCodeIsNotClaimed() {
    var tracker = OTPSubmissionTracker()

    #expect(tracker.claimCode("12345", requiredLength: 6) == nil)
  }

  @Test
  func editingCodeAllowsSameValueToBeSubmittedAgain() {
    var tracker = OTPSubmissionTracker()

    #expect(tracker.claimCode("123456", requiredLength: 6) == "123456")

    tracker.codeDidChange(to: "12345", requiredLength: 6)

    #expect(tracker.claimCode("123456", requiredLength: 6) == "123456")
  }

  @Test
  func replacingCompleteCodeClaimsNewValue() {
    var tracker = OTPSubmissionTracker()

    #expect(tracker.claimCode("123456", requiredLength: 6) == "123456")
    #expect(tracker.claimCode("654321", requiredLength: 6) == "654321")
  }
}

struct OTPVerificationAttemptTrackerTests {
  @Test
  func currentAttemptCompletesOnce() {
    var tracker = OTPVerificationAttemptTracker()
    let attemptID = tracker.begin()
    let firstCompletion = tracker.complete(attemptID)
    let secondCompletion = tracker.complete(attemptID)

    #expect(firstCompletion)
    #expect(!secondCompletion)
  }

  @Test
  func newerAttemptMakesEarlierAttemptStale() {
    var tracker = OTPVerificationAttemptTracker()
    let earlierAttemptID = tracker.begin()
    let newerAttemptID = tracker.begin()
    let earlierAttemptCompleted = tracker.complete(earlierAttemptID)
    let newerAttemptCompleted = tracker.complete(newerAttemptID)

    #expect(!earlierAttemptCompleted)
    #expect(newerAttemptCompleted)
  }
}

#endif
