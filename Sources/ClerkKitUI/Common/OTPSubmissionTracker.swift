//
//  OTPSubmissionTracker.swift
//  Clerk
//

#if os(iOS) || os(macOS)

struct OTPSubmissionTracker {
  private var lastSubmittedCode: String?
  private(set) var activeCode: String?
  private var isExecuting = false

  mutating func codeDidChange(to code: String, requiredLength: Int) -> Bool {
    guard activeCode == nil else { return false }

    if code.count < requiredLength {
      lastSubmittedCode = nil
      return false
    }

    guard code.count == requiredLength,
          code != lastSubmittedCode
    else {
      return false
    }

    activeCode = code
    lastSubmittedCode = code
    return true
  }

  mutating func beginSubmission() -> String? {
    guard !isExecuting, let activeCode else { return nil }
    isExecuting = true
    return activeCode
  }

  mutating func cancelSubmission() {
    activeCode = nil
    isExecuting = false
  }

  mutating func completeSubmission(
    currentCode: String,
    requiredLength: Int,
    disposition: OTPSubmissionDisposition
  ) -> String? {
    activeCode = nil

    guard disposition == .submitPendingCode,
          currentCode.count == requiredLength,
          currentCode != lastSubmittedCode
    else {
      isExecuting = false
      return nil
    }

    activeCode = currentCode
    lastSubmittedCode = currentCode
    return currentCode
  }
}

#endif
