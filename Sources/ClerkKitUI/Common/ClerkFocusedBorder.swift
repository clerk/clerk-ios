//
//  ClerkFocusedBorder.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct ClerkFocusedBorder: ViewModifier {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.self) private var environment

  enum BorderState {
    case `default`
    case error
  }

  var innerBorderColor: Color {
    switch state {
    case .default:
      isFocused ? theme.colors.inputBorderFocused : theme.colors.inputBorder
    case .error:
      theme.colors.dangerInputBorder
    }
  }

  var outerBorderColor: Color {
    switch state {
    case .default:
      theme.colors.inputBorder
    case .error:
      theme.colors.dangerInputBorderFocused
    }
  }

  let isFocused: Bool
  var state: BorderState = .default

  func body(content: Content) -> some View {
    content
      .overlay {
        ring(color: innerBorderColor, width: 1, isInset: true)
      }
      .background {
        ring(color: outerBorderColor, width: isFocused ? 4 : 0, isInset: false)
      }
  }

  private func ring(color: Color, width: CGFloat, isInset: Bool) -> some View {
    let resolvedColor = color.resolve(in: environment)
    let ring = AnimatedFocusRing(
      color: resolvedColor,
      width: width,
      cornerRadius: theme.design.borderRadius,
      isInset: isInset
    )
    return ring.animation(.default, value: ring.animatableData)
  }
}

private nonisolated struct AnimatedFocusRing: View, Animatable {
  var color: Color.Resolved
  var width: CGFloat
  var cornerRadius: CGFloat
  let isInset: Bool

  var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Color.Resolved.AnimatableData> {
    get { AnimatablePair(AnimatablePair(width, cornerRadius), color.animatableData) }
    set {
      width = newValue.first.first
      cornerRadius = newValue.first.second
      color.animatableData = newValue.second
    }
  }

  @MainActor
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius)
    if isInset {
      shape.strokeBorder(Color(color), lineWidth: width)
        .transaction { $0.animation = nil }
    } else {
      shape.stroke(Color(color), lineWidth: width)
        .transaction { $0.animation = nil }
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
