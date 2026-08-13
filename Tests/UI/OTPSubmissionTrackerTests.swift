#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

struct OTPSubmissionTrackerTests {
  @Test
  func completeCodeStartsSubmission() {
    var tracker = OTPSubmissionTracker()

    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()

    #expect(didStart)
    #expect(submittedCode == "123456")
  }

  @Test
  func incompleteCodeDoesNotStartSubmission() {
    var tracker = OTPSubmissionTracker()

    let didStart = tracker.codeDidChange(to: "12345", requiredLength: 6)

    #expect(!didStart)
    #expect(tracker.activeCode == nil)
  }

  @Test
  func editingWhileSubmittingDoesNotStartOverlappingRequest() {
    var tracker = OTPSubmissionTracker()

    let didStartOriginalCode = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()
    let didStartIncompleteCode = tracker.codeDidChange(to: "12345", requiredLength: 6)
    let didStartEditedCode = tracker.codeDidChange(to: "123457", requiredLength: 6)

    #expect(didStartOriginalCode)
    #expect(submittedCode == "123456")
    #expect(!didStartIncompleteCode)
    #expect(!didStartEditedCode)
    #expect(tracker.activeCode == "123456")
  }

  @Test
  func incorrectCodeSubmitsEditedCompleteCodeNext() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()

    let nextCode = tracker.completeSubmission(
      currentCode: "123457",
      requiredLength: 6,
      disposition: .submitPendingCode
    )

    #expect(didStart)
    #expect(submittedCode == "123456")
    #expect(nextCode == "123457")
    #expect(tracker.activeCode == "123457")
  }

  @Test
  func terminalErrorDoesNotSubmitEditedCode() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()

    let nextCode = tracker.completeSubmission(
      currentCode: "123457",
      requiredLength: 6,
      disposition: .stop
    )

    #expect(didStart)
    #expect(submittedCode == "123456")
    #expect(nextCode == nil)
    #expect(tracker.activeCode == nil)
  }

  @Test
  func unchangedIncorrectCodeIsNotResubmittedAutomatically() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()

    let nextCode = tracker.completeSubmission(
      currentCode: "123456",
      requiredLength: 6,
      disposition: .submitPendingCode
    )

    #expect(didStart)
    #expect(submittedCode == "123456")
    #expect(nextCode == nil)
    #expect(tracker.activeCode == nil)
  }

  @Test
  func editingAfterCompletionAllowsIntentionalRetry() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()
    _ = tracker.completeSubmission(
      currentCode: "123456",
      requiredLength: 6,
      disposition: .stop
    )

    let didStartIncompleteCode = tracker.codeDidChange(to: "12345", requiredLength: 6)
    let didStartRetry = tracker.codeDidChange(to: "123456", requiredLength: 6)

    #expect(didStart)
    #expect(submittedCode == "123456")
    #expect(!didStartIncompleteCode)
    #expect(didStartRetry)
  }

  @Test
  func reappearingTaskDoesNotSubmitUnchangedCodeAgain() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()
    _ = tracker.completeSubmission(
      currentCode: "123456",
      requiredLength: 6,
      disposition: .stop
    )

    let didRestart = tracker.codeDidChange(to: "123456", requiredLength: 6)

    #expect(didStart)
    #expect(submittedCode == "123456")
    #expect(!didRestart)
  }

  @Test
  func reappearingTaskCannotAcquireInFlightSubmission() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let firstTaskCode = tracker.beginSubmission()
    let reappearingTaskCode = tracker.beginSubmission()

    #expect(didStart)
    #expect(firstTaskCode == "123456")
    #expect(reappearingTaskCode == nil)
  }

  @Test
  func canceledSubmissionRequiresAnIntentionalRetry() {
    var tracker = OTPSubmissionTracker()
    let didStart = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let submittedCode = tracker.beginSubmission()

    tracker.cancelSubmission()

    let didRestartUnchangedCode = tracker.codeDidChange(to: "123456", requiredLength: 6)
    let didStartIncompleteCode = tracker.codeDidChange(to: "12345", requiredLength: 6)
    let didStartRetry = tracker.codeDidChange(to: "123456", requiredLength: 6)

    #expect(didStart)
    #expect(submittedCode == "123456")
    #expect(!didRestartUnchangedCode)
    #expect(!didStartIncompleteCode)
    #expect(didStartRetry)
  }
}

struct OTPSubmissionDispositionTests {
  @Test
  func incorrectCodeAllowsPendingSubmission() {
    let error = ClerkAPIError(
      code: "form_code_incorrect",
      message: nil,
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    #expect(error.otpSubmissionDisposition == .submitPendingCode)
  }

  @Test(
    "Other errors stop pending submission",
    arguments: [
      "too_many_requests",
      "signed_out",
      "verification_already_verified",
    ]
  )
  func apiErrorStopsPendingSubmission(code: String) {
    let error = ClerkAPIError(
      code: code,
      message: nil,
      longMessage: nil,
      meta: nil,
      clerkTraceId: nil
    )

    #expect(error.otpSubmissionDisposition == .stop)
  }

  @Test
  func networkErrorStopsPendingSubmission() {
    let error = URLError(.timedOut)

    #expect(error.otpSubmissionDisposition == .stop)
  }
}

#endif
