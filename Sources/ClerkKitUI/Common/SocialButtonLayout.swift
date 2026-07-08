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
    SocialButtonLayoutConfiguration.stacksTwoItemsInSingleColumn(horizontalSizeClass: horizontalSizeClass)
    #else
    SocialButtonLayoutConfiguration.stacksTwoItemsInSingleColumn()
    #endif
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 50) {
      SocialButtonGroup(providers: [.google]) { provider, showsTitle, _ in
        SocialButton(provider: provider, showsTitle: showsTitle)
      }

      SocialButtonGroup(providers: [.google, .apple]) { provider, showsTitle, _ in
        SocialButton(provider: provider, showsTitle: showsTitle)
      }

      SocialButtonGroup(providers: [.google, .apple, .github]) { provider, showsTitle, _ in
        SocialButton(provider: provider, showsTitle: showsTitle)
      }

      SocialButtonGroup(providers: [.google, .apple, .github, .slack]) { provider, showsTitle, _ in
        SocialButton(provider: provider, showsTitle: showsTitle)
      }

      SocialButtonGroup(providers: [.google, .apple, .github, .slack, .facebook]) { provider, showsTitle, _ in
        SocialButton(provider: provider, showsTitle: showsTitle)
      }

      SocialButtonGroup(providers: [.google, .apple, .github, .slack, .facebook, .discord]) { provider, showsTitle, _ in
        SocialButton(provider: provider, showsTitle: showsTitle)
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
  .environment(Clerk.preview())
}

#endif
