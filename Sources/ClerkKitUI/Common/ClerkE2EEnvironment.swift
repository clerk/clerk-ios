//
//  ClerkE2EEnvironment.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation

enum ClerkE2EEnvironment {
  /// Enables only narrow UI automation workarounds for E2EHost.
  ///
  /// Keep usage limited to OS-level automation interference, such as password
  /// AutoFill prompts. Do not use this to bypass Clerk validation, routing,
  /// backend calls, feature flags, session state, or other product behavior.
  static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["CLERK_E2E_MODE"] == "1"
  }
}

#endif
