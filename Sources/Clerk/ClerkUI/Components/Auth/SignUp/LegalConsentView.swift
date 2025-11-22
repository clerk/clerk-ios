//
//  LegalConsentView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/23/25.
//

#if os(iOS)

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
        var text = String(localized: "I agree to the ", bundle: .module)

        if hasTerms {
            text += "[\(String(localized: "Terms of Service", bundle: .module))](LegalConsentView://terms)"
            if hasPrivacy {
                text += String(localized: " and ", bundle: .module)
            }
        }

        if hasPrivacy {
            text += "[\(String(localized: "Privacy Policy", bundle: .module))](LegalConsentView://privacy)"
        }

        return text
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

