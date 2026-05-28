//
//  SecuredByClerkView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SecuredByClerkView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private var showsSecuredByClerk: Bool {
    clerk.environment?.displayConfig.branded == true
  }

  var body: some View {
    if showsSecuredByClerk {
      HStack(spacing: 6) {
        Text("Secured by", bundle: .module)
        Image("clerk-logo", bundle: .module)
          .accessibilityHidden(true)
      }
      .font(theme.fonts.footnote.weight(.medium))
      .foregroundStyle(theme.colors.mutedForeground)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Secured by", bundle: .module) + Text(verbatim: " Clerk"))
    }
  }
}

struct SecuredByClerkFooter: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private var showsFooter: Bool {
    clerk.shouldShowDevelopmentModeWarning || showsSecuredByClerk
  }

  private var showsSecuredByClerk: Bool {
    clerk.environment?.displayConfig.branded == true
  }

  var body: some View {
    if showsFooter {
      VStack(spacing: 9) {
        SecuredByClerkView()

        if clerk.shouldShowDevelopmentModeWarning {
          DevelopmentModeFooterView()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, clerk.shouldShowDevelopmentModeWarning ? 0 : 16)
      .frame(maxWidth: .infinity)
      .background {
        Group {
          if clerk.shouldShowDevelopmentModeWarning {
            DevelopmentModeBackgroundView(background: .gray)
          } else {
            theme.colors.muted
          }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .allowsHitTesting(false)
      }
      .overlay(alignment: .top) {
        Rectangle()
          .fill(theme.colors.border)
          .frame(height: 1)
      }
    }
  }
}

extension View {
  func securedByClerkFooter() -> some View {
    modifier(SecuredByClerkFooterModifier())
  }
}

private struct SecuredByClerkFooterModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .safeAreaInset(edge: .bottom, spacing: 0) {
        SecuredByClerkFooter()
      }
  }
}

#Preview {
  SecuredByClerkView()
}

#Preview {
  @Previewable @Environment(\.clerkTheme) var theme

  VStack(spacing: 0) {
    ScrollView {
      theme.colors.muted
        .containerRelativeFrame(.vertical)
    }
    SecuredByClerkFooter()
  }
}

#endif
