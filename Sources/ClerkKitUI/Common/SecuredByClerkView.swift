//
//  SecuredByClerkView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

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

  init(showBackground: Bool = true) {
    self.showBackground = showBackground
  }

  var body: some View {
    if clerk.shouldShowSecuredByClerkFooter {
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
          Group {
            if clerk.shouldShowDevelopmentModeWarning {
              DevelopmentModeBackgroundView(background: .gray)
            } else {
              theme.colors.muted
            }
          }
          .ignoresSafeArea(.container, edges: .bottom)
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
  @Environment(Clerk.self) private var clerk

  func body(content: Content) -> some View {
    content
      .bottomTrackedFooter(isPresented: clerk.shouldShowSecuredByClerkFooter) {
        SecuredByClerkFooter()
      }
  }
}

extension Clerk {
  fileprivate var shouldShowSecuredByClerkFooter: Bool {
    shouldShowDevelopmentModeWarning || environment?.displayConfig.branded == true
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
