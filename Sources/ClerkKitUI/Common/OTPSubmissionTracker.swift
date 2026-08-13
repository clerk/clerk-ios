//
//  OTPSubmissionTracker.swift
//  Clerk
//

#if os(iOS) || os(macOS)

struct OTPSubmissionTracker {
  private var lastSubmittedCode: String?

  mutating func codeDidChange(to code: String, requiredLength: Int) {
    if code.count < requiredLength {
      lastSubmittedCode = nil
    }
  }

  mutating func claimCode(_ code: String, requiredLength: Int) -> String? {
    guard code.count == requiredLength,
          code != lastSubmittedCode
    else {
      return nil
    }

    lastSubmittedCode = code
    return code
  }
}

struct OTPVerificationAttemptTracker {
  private var nextAttemptID = 0
  private var activeAttemptID: Int?

  mutating func begin() -> Int {
    nextAttemptID += 1
    activeAttemptID = nextAttemptID
    return nextAttemptID
  }

  mutating func complete(_ attemptID: Int) -> Bool {
    guard activeAttemptID == attemptID else { return false }
    activeAttemptID = nil
    return true
  }
}

#endif
