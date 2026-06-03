//
//  AtlantisModifier.swift
//  MacExampleApp
//

import Atlantis
import SwiftUI

extension View {
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
