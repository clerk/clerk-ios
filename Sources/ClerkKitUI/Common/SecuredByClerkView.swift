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
  private let macOSDismissAction: (() -> Void)?

  init(
    showBackground: Bool = true,
    macOSDismissAction: (() -> Void)? = nil
  ) {
    self.showBackground = showBackground
    self.macOSDismissAction = macOSDismissAction
  }

  var body: some View {
    if shouldShowFooter {
      VStack(spacing: 9) {
        if clerk.shouldShowSecuredByClerkFooter {
          SecuredByClerkView()

          if clerk.shouldShowDevelopmentModeWarning {
            DevelopmentModeView()
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, bottomPadding)
      .frame(maxWidth: .infinity)
      .background {
        if showBackground {
          Group {
            #if os(macOS)
            theme.colors.muted
            #else
            if clerk.shouldShowDevelopmentModeWarning {
              DevelopmentModeBackgroundView(background: .gray)
            } else {
              theme.colors.muted
            }
            #endif
          }
          .ignoresSafeArea(.container, edges: .bottom)
        }
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

  private var shouldShowFooter: Bool {
    #if os(macOS)
    clerk.shouldShowSecuredByClerkFooter || macOSDismissAction != nil
    #else
    clerk.shouldShowSecuredByClerkFooter
    #endif
  }

  private var bottomPadding: CGFloat {
    #if os(macOS)
    16
    #else
    clerk.shouldShowDevelopmentModeWarning ? 0 : 16
    #endif
  }
}

extension View {
  func securedByClerkFooter(macOSDismissAction: (() -> Void)? = nil) -> some View {
    modifier(
      SecuredByClerkFooterModifier(macOSDismissAction: macOSDismissAction)
    )
  }
}

private struct SecuredByClerkFooterModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk

  private let macOSDismissAction: (() -> Void)?

  init(macOSDismissAction: (() -> Void)? = nil) {
    self.macOSDismissAction = macOSDismissAction
  }

  func body(content: Content) -> some View {
    if usesInteractiveFooter {
      content
        .safeAreaInset(edge: .bottom, spacing: 0) {
          SecuredByClerkFooter(macOSDismissAction: macOSDismissAction)
        }
    } else {
      content
        .bottomTrackedFooter(isPresented: clerk.shouldShowSecuredByClerkFooter) {
          SecuredByClerkFooter()
        }
    }
  }

  private var usesInteractiveFooter: Bool {
    #if os(macOS)
    macOSDismissAction != nil
    #else
    false
    #endif
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
