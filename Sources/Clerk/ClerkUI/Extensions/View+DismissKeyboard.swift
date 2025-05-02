//
//  View+DismissKeyboard.swift
//  Clerk
//
//  Created by Mike Pitre on 4/28/25.
//

#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI

  extension EnvironmentValues {
    var dismissKeyboard: @MainActor () -> Void {
      get { self[DismissKeyboardKey.self] }
      set { self[DismissKeyboardKey.self] = newValue }
    }
  }

  // Create a custom environment key
  private struct DismissKeyboardKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: @MainActor () -> Void = {
      _ = UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
  }
#endif
