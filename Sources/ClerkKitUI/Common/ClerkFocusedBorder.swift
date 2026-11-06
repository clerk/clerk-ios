//
//  ClerkFocusedBorder.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct ClerkFocusedBorder: ViewModifier {
  @Environment(\.clerkTheme) private var theme

  enum BorderState {
    case `default`
    case error
  }

  let isFocused: Bool
  var state: BorderState = .default

  func body(content: Content) -> some View {
    content
      .overlay { ring(.innerBorder) }
      .background { ring(.outerRing) }
  }

  private func ring(_ layer: FocusRing.Layer) -> some View {
    FocusRing(
      layer: layer,
      focusProgress: isFocused ? 1 : 0,
      errorProgress: state == .error ? 1 : 0,
      cornerRadius: theme.design.borderRadius,
      border: theme.colors.inputBorder,
      focusedBorder: theme.colors.inputBorderFocused,
      errorBorder: theme.colors.dangerInputBorder,
      errorRing: theme.colors.dangerInputBorderFocused
    )
    .animation(.default, value: isFocused)
    .animation(.default, value: state)
  }
}

private nonisolated struct FocusRing: View, Animatable {
  enum Layer {
    case innerBorder, outerRing
  }

  let layer: Layer
  var focusProgress: Double
  var errorProgress: Double
  let cornerRadius: CGFloat
  let border: Color
  let focusedBorder: Color
  let errorBorder: Color
  let errorRing: Color

  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(focusProgress, errorProgress) }
    set {
      focusProgress = newValue.first
      errorProgress = newValue.second
    }
  }

  @MainActor
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius)
    switch layer {
    case .innerBorder:
      ZStack {
        shape.strokeBorder(border, lineWidth: 1)
        shape.strokeBorder(focusedBorder, lineWidth: 1)
          .opacity(focusProgress * (1 - errorProgress))
        shape.strokeBorder(errorBorder, lineWidth: 1)
          .opacity(errorProgress)
      }
    case .outerRing:
      ZStack {
        shape.stroke(border, lineWidth: 4 * focusProgress)
        shape.stroke(errorRing, lineWidth: 4 * focusProgress)
          .opacity(errorProgress)
      }
    }
  }
}

extension View {
  func clerkFocusedBorder(isFocused: Bool = true, state: ClerkFocusedBorder.BorderState = .default) -> some View {
    modifier(ClerkFocusedBorder(isFocused: isFocused, state: state))
  }
}

#Preview {
  @Previewable @Environment(\.clerkTheme) var theme

  VStack(spacing: 20) {
    RoundedRectangle(cornerRadius: theme.design.borderRadius)
      .fill(theme.colors.background)
      .frame(maxWidth: .infinity, maxHeight: 48)
      .clerkFocusedBorder(isFocused: false)

    RoundedRectangle(cornerRadius: theme.design.borderRadius)
      .fill(theme.colors.background)
      .frame(maxWidth: .infinity, maxHeight: 48)
      .clerkFocusedBorder()

    RoundedRectangle(cornerRadius: theme.design.borderRadius)
      .fill(theme.colors.background)
      .frame(maxWidth: .infinity, maxHeight: 48)
      .clerkFocusedBorder(isFocused: false, state: .error)

    RoundedRectangle(cornerRadius: theme.design.borderRadius)
      .fill(theme.colors.background)
      .frame(maxWidth: .infinity, maxHeight: 48)
      .clerkFocusedBorder(state: .error)
  }
  .padding()
}

#endif
