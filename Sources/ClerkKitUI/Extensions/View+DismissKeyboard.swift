//
//  View+DismissKeyboard.swift
//  Clerk
//

#if os(iOS) || os(macOS)
#if os(macOS)
import AppKit
#endif
import SwiftUI

extension EnvironmentValues {
  var dismissKeyboard: @MainActor () -> Void {
    get { self[DismissKeyboardKey.self] }
    set { self[DismissKeyboardKey.self] = newValue }
  }
}

/// Create a custom environment key
private struct DismissKeyboardKey: @preconcurrency EnvironmentKey {
  @MainActor static let defaultValue: @MainActor () -> Void = {
    #if os(iOS)
    _ = UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #elseif os(macOS)
    let window = NSApp.keyWindow ?? NSApp.mainWindow
    _ = window?.makeFirstResponder(nil)
    #endif
  }
}
#endif
