//
//  SignInPasswordActionsView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct SignInPasswordActionsView: View {
  @Environment(\.clerkTheme) private var theme

  let onUseAnotherMethod: () -> Void
  let onForgotPassword: () -> Void

  var body: some View {
    ActionsLayout {
      Button(action: onUseAnotherMethod) {
        Text("Use another method", bundle: .module)
          .frame(maxWidth: .infinity)
      }
      .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SignIn.useAnotherMethodButton)

      Rectangle()
        .foregroundStyle(theme.colors.border)
        .frame(width: 1, height: 16)

      Button(action: onForgotPassword) {
        Text("Forgot password?", bundle: .module)
          .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
    .simultaneousGesture(TapGesture())
  }

  /// Private to the row that owns the two buttons and their divider.
  private struct ActionsLayout: Layout {
    static var layoutProperties: LayoutProperties {
      HStackLayout.layoutProperties
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
      let stack = stack(width: proposal.width, subviews: subviews)
      var cache = stack.makeCache(subviews: subviews)
      return stack.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
      let stack = stack(width: bounds.width, subviews: subviews)
      var cache = stack.makeCache(subviews: subviews)
      stack.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
    }

    private func stack(width: CGFloat?, subviews: Subviews) -> some Layout {
      // Measuring the styled buttons includes their padding and respects the current
      // font and locale. The enclosing view owns their order around the divider.
      guard subviews.count == 3, let width, width.isFinite else {
        return HStackLayout(spacing: 16)
      }

      let buttonWidth = max(
        subviews[0].sizeThatFits(.unspecified).width,
        subviews[2].sizeThatFits(.unspecified).width
      )
      let dividerWidth = subviews[1].sizeThatFits(.unspecified).width
      let requiredWidth = buttonWidth * 2 + dividerWidth + 16 * 2
      return HStackLayout(spacing: width >= requiredWidth ? 16 : 8)
    }
  }
}

#endif
