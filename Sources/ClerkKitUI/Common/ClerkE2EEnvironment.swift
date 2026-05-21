//
//  ClerkE2EEnvironment.swift
//  Clerk
//

#if os(iOS)

import Foundation

enum ClerkE2EEnvironment {
  static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["CLERK_E2E_MODE"] == "1"
  }
}

#endif
