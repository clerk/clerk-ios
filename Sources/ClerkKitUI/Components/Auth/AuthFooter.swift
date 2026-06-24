//
//  AuthFooter.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

extension View {
  func authFooter(
    developmentModeBackground: DevelopmentModeBackground = .white,
    macOSDismissAction: (() -> Void)? = nil
  ) -> some View {
    modifier(
      AuthFooterModifier(
        developmentModeBackground: developmentModeBackground,
        macOSDismissAction: macOSDismissAction
      )
    )
  }
}

private struct AuthFooterModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk

  let developmentModeBackground: DevelopmentModeBackground
  let macOSDismissAction: (() -> Void)?

  func body(content: Content) -> some View {
    #if os(macOS)
    content
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if shouldShowMacOSFooter {
          AuthFooter(macOSDismissAction: macOSDismissAction)
        }
      }
    #else
    content
      .bottomTrackedFooter(isPresented: clerk.shouldShowDevelopmentModeWarning) {
        DevelopmentModeView()
          .offset(y: 8) // nudge the label toward the bottom line; grid (background) stays put
          .padding(.top, 16)
          .frame(maxWidth: .infinity)
          .background {
            DevelopmentModeBackgroundView(background: developmentModeBackground)
              .ignoresSafeArea(.container, edges: .bottom)
          }
      }
    #endif
  }

  private var shouldShowMacOSFooter: Bool {
    #if os(macOS)
    clerk.shouldShowDevelopmentModeWarning || macOSDismissAction != nil
    #else
    false
    #endif
  }
}

private struct AuthFooter: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme

  let macOSDismissAction: (() -> Void)?

  var body: some View {
    VStack(spacing: 0) {
      if clerk.shouldShowDevelopmentModeWarning {
        DevelopmentModeView()
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity)
    .background {
      theme.colors.muted
        .ignoresSafeArea(.container, edges: .bottom)
    }
    .overlay(alignment: .top) {
      Rectangle()
        .fill(theme.colors.border)
        .frame(height: 1)
    }
    #if os(macOS)
    .overlay(alignment: .trailing) {
      if let macOSDismissAction {
        Button {
          macOSDismissAction()
        } label: {
          Text("Close", bundle: .module)
        }
        .keyboardShortcut(.cancelAction)
        .padding(.trailing, 16)
      }
    }
    #endif
  }
}

#endif
