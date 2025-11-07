//
//  PreviewUtils.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Utility functions for detecting SwiftUI preview environment.
package enum PreviewUtils {
  /// Checks if the current process is running in a SwiftUI preview.
  package static var isRunningInPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }
}
