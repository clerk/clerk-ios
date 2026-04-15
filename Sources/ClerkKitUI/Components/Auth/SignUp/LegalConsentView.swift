//
//  LegalConsentView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct LegalConsentView: View {
  @Environment(\.clerkTheme) private var theme

  @Binding var isAccepted: Bool
  let onTermsTap: (() -> Void)?
  let onPrivacyTap: (() -> Void)?

  var hasTerms: Bool {
    onTermsTap != nil
  }

  var hasPrivacy: Bool {
    onPrivacyTap != nil
  }

  var hasTermsOrPrivacy: Bool {
    hasTerms || hasPrivacy
  }

  private var markdownText: String {
    switch (hasTerms, hasPrivacy) {
    case (true, true):
      String(
        localized: "I agree to the [Terms of Service](LegalConsentView://terms) and [Privacy Policy](LegalConsentView://privacy)",
        bundle: .module
      )
    case (true, false):
      String(
        localized: "I agree to the [Terms of Service](LegalConsentView://terms)",
        bundle: .module
      )
    case (false, true):
      String(
        localized: "I agree to the [Privacy Policy](LegalConsentView://privacy)",
        bundle: .module
      )
    case (false, false):
      ""
    }
  }

  var body: some View {
    if !hasTermsOrPrivacy {
      EmptyView()
    } else {
      HStack(alignment: .top, spacing: 12) {
        Text(.init(markdownText))
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .tint(theme.colors.primary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "LegalConsentView", url.host == "terms", hasTerms {
              onTermsTap?()
              return .handled
            } else if url.scheme == "LegalConsentView", url.host == "privacy", hasPrivacy {
              onPrivacyTap?()
              return .handled
            }
            return .systemAction
          })

        Toggle("", isOn: $isAccepted)
          .labelsHidden()
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.foreground)
          .tint(theme.colors.primary)
          .frame(minHeight: 22)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(theme.colors.muted, in: .rect(cornerRadius: theme.design.borderRadius))
    }
  }
}

#Preview {
  @Previewable @State var isAccepted = false

  VStack(spacing: 20) {
    LegalConsentView(
      isAccepted: $isAccepted,
      onTermsTap: {},
      onPrivacyTap: {}
    )

    LegalConsentView(
      isAccepted: $isAccepted,
      onTermsTap: {},
      onPrivacyTap: nil
    )

    LegalConsentView(
      isAccepted: $isAccepted,
      onTermsTap: nil,
      onPrivacyTap: {}
    )

    LegalConsentView(
      isAccepted: $isAccepted,
      onTermsTap: nil,
      onPrivacyTap: nil
    )
  }
  .padding()
}

#endif
