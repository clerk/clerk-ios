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
    if code.count < requiredLength {
      lastSubmittedCode = nil
      return false
    }

    guard activeCode == nil else { return false }

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

  mutating func beginSubmission(
    for currentCode: String,
    requiredLength: Int
  ) -> String? {
    if activeCode == nil {
      _ = codeDidChange(to: currentCode, requiredLength: requiredLength)
    }

    return beginSubmission()
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
    let completedCode = activeCode
    activeCode = nil

    guard let completedCode,
          disposition == .submitPendingCode,
          currentCode.count == requiredLength,
          currentCode != completedCode
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
