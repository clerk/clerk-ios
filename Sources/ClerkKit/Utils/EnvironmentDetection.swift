//
//  EnvironmentDetection.swift
//  Clerk
//
//  Created by Assistant on 2025-01-27.
//

import Foundation

/// Utilities for detecting the runtime environment.
package enum EnvironmentDetection {
  /// Returns `true` if the code is currently running in SwiftUI previews.
  ///
  /// This is detected by checking if the process is running in Xcode's preview environment.
  package static var isRunningInPreviews: Bool {
    #if DEBUG
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    #else
    return false
    #endif
  }

  /// Returns `true` if the code is currently running in unit tests.
  ///
  /// This is detected by checking for test-related process arguments or environment variables
  /// that are set when running tests in Xcode or via Swift Testing.
  package static var isRunningInTests: Bool {
    #if DEBUG
    let processInfo = ProcessInfo.processInfo

    // Check for Xcode test arguments
    if processInfo.arguments.contains("-XCTest") {
      return true
    }

    // Check for Swift Testing environment variable
    if processInfo.environment["SWIFT_DETERMINISTIC_HASHING"] != nil {
      return true
    }

    // Check for test bundle identifier
    if let bundleIdentifier = Bundle.main.bundleIdentifier,
       bundleIdentifier.contains("xctest") || bundleIdentifier.contains("Tests")
    {
      return true
    }

    return false
    #else
    return false
    #endif
  }
}
