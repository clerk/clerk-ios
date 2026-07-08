//
//  SocialButtonLayout.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SocialButtonLayout<Content: View>: View {
  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    SocialButtonRowsLayout(stacksTwoItemsInSingleColumn: stacksTwoItemsInSingleColumn) {
      content
    }
  }

  private var stacksTwoItemsInSingleColumn: Bool {
    #if os(iOS)
    horizontalSizeClass == .compact
    #else
    false
    #endif
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 50) {
      SocialButtonLayout {
        SocialButton(provider: .google)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
        SocialButton(provider: .github, showsTitle: false)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
        SocialButton(provider: .github, showsTitle: false)
        SocialButton(provider: .slack, showsTitle: false)
      }

      SocialButtonLayout {
        SocialButton(provider: .google, showsTitle: false)
        SocialButton(provider: .apple, showsTitle: false)
        SocialButton(provider: .github, showsTitle: false)
        SocialButton(provider: .slack, showsTitle: false)
        SocialButton(provider: .facebook, showsTitle: false)
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
  .environment(Clerk.preview())
}

#endif
