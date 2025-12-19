//
//  AtlantisModifier.swift
//  WatchExampleApp Watch App
//
//  Created on 2025-01-27.
//

import Atlantis
import SwiftUI

extension View {
  /// Enables Atlantis network debugging in DEBUG builds.
  /// This modifier should be applied to the root view of your app.
  func atlantisProxy() -> some View {
    modifier(AtlantisDebugModifier())
  }
}

private struct AtlantisDebugModifier: ViewModifier {
  #if DEBUG
  @State private var hasStarted = false

  func body(content: Content) -> some View {
    content
      .task {
        if !hasStarted {
          Atlantis.start()
          hasStarted = true
        }
      }
  }
  #else
  func body(content: Content) -> some View {
    content
  }
  #endif
}
