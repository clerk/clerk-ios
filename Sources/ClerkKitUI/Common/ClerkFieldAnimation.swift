//
//  ClerkFieldAnimation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

/// Custom Animatable bodies keep these effects out of SwiftUI's asynchronous
/// presentation-modifier commits, which can contend with keyboard layout (#820).
nonisolated struct ClerkFloatingLabel: ViewModifier, Animatable {
  var progress: CGFloat
  let offset: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  @MainActor
  func body(content: Content) -> some View {
    content
      .offset(y: -offset * progress)
      .scaleEffect(1 - (5.0 / 17.0) * progress, anchor: .topLeading)
  }
}

nonisolated struct ClerkFieldOpacity: ViewModifier, Animatable {
  var opacity: Double

  var animatableData: Double {
    get { opacity }
    set { opacity = newValue }
  }

  @MainActor
  func body(content: Content) -> some View {
    content.opacity(opacity)
  }
}

extension AnyTransition {
  static var clerkFieldOpacity: AnyTransition {
    .modifier(active: ClerkFieldOpacity(opacity: 0), identity: ClerkFieldOpacity(opacity: 1))
  }
}

#endif
