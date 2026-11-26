//
//  ClerkDismissAction.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

extension EnvironmentValues {
  @Entry var presentedSheetDismiss: (@MainActor () -> Void)?
}

/// Closes the sheet Clerk presented itself, which SwiftUI's `dismiss` can't reach, or else
/// does what `dismiss` does.
struct ClerkDismissAction: DynamicProperty {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.presentedSheetDismiss) private var presentedSheetDismiss

  @MainActor
  func callAsFunction() {
    if let presentedSheetDismiss {
      presentedSheetDismiss()
    } else {
      dismiss()
    }
  }
}

#endif
