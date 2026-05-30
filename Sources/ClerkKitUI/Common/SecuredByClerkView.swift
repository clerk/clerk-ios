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

  var body: some View {
    if clerk.environment?.displayConfig.branded == true {
      HStack(spacing: 6) {
        Text("Secured by", bundle: .module)
        Image("clerk-logo", bundle: .module)
      }
      .font(theme.fonts.footnote.weight(.medium))
      .foregroundStyle(theme.colors.mutedForeground)
      .transition(.blurReplace.animation(.default))
    } else {
      EmptyView()
    }
  }
}

struct SecuredByClerkFooter: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  private let showBackground: Bool

  private var showsFooter: Bool {
    clerk.shouldShowDevelopmentModeWarning || showsSecuredByClerk
  }

  private var showsSecuredByClerk: Bool {
    clerk.environment?.displayConfig.branded == true
  }

  init(showBackground: Bool = true) {
    self.showBackground = showBackground
  }

  var body: some View {
    if showsFooter {
      VStack(spacing: 9) {
        SecuredByClerkView()

        if clerk.shouldShowDevelopmentModeWarning {
          DevelopmentModeView()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, clerk.shouldShowDevelopmentModeWarning ? 0 : 16)
      .frame(maxWidth: .infinity)
      .background {
        if showBackground {
          if clerk.shouldShowDevelopmentModeWarning {
            DevelopmentModeBackgroundView(background: .gray)
              .ignoresSafeArea(.container, edges: .bottom)
          } else {
            theme.colors.muted
          }
        }
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
