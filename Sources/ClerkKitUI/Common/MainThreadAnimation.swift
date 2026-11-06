//
//  MainThreadAnimation.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

// SwiftUI commits animations of built-in effects (opacity, offset, scale, rotation,
// color) from its AsyncRenderer thread. On iOS 26 and 27 that thread can deadlock
// with the main thread while the keyboard lays out its input views
// (https://github.com/clerk/clerk-ios/issues/820). SwiftUI interpolates an
// `Animatable` modifier by evaluating its body each frame on the main thread
// instead, so views that animate while a field gains focus or while the keyboard
// is up use the modifiers in this file. Drive them with `.animation(_:value:)` or
// `withAnimation`: under the scoped `.animation(_:body:)` form, SwiftUI still
// commits a text field's animation from the AsyncRenderer thread.

nonisolated struct MainThreadOpacity: ViewModifier, Animatable {
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

nonisolated struct MainThreadRotation: ViewModifier, Animatable {
  var degrees: Double

  var animatableData: Double {
    get { degrees }
    set { degrees = newValue }
  }

  @MainActor
  func body(content: Content) -> some View {
    content.rotationEffect(.degrees(degrees))
  }
}

nonisolated struct MainThreadFloatingLabel: ViewModifier, Animatable {
  static let floatedScale: CGFloat = 12 / 17

  var progress: CGFloat
  let floatedOffset: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  @MainActor
  func body(content: Content) -> some View {
    content
      .offset(y: -floatedOffset * progress)
      .scaleEffect(1 - (1 - Self.floatedScale) * progress, anchor: .topLeading)
  }
}

extension View {
  func mainThreadOpacity(_ opacity: Double) -> some View {
    modifier(MainThreadOpacity(opacity: opacity))
  }

  func mainThreadRotation(degrees: Double) -> some View {
    modifier(MainThreadRotation(degrees: degrees))
  }

  func mainThreadFloatingLabel(isFloating: Bool, offset: CGFloat) -> some View {
    modifier(MainThreadFloatingLabel(progress: isFloating ? 1 : 0, floatedOffset: offset))
  }
}

extension AnyTransition {
  static var mainThreadOpacity: AnyTransition {
    .modifier(active: MainThreadOpacity(opacity: 0), identity: MainThreadOpacity(opacity: 1))
  }
}

#endif
