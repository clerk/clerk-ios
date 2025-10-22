//
//  SecuredByClerkView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

import SwiftUI

struct SecuredByClerkView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    var body: some View {
        if clerk.environment.displayConfig?.branded == true {
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
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme

    var body: some View {
        if clerk.environment.displayConfig?.branded == true {
            SecuredByClerkView()
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(theme.colors.muted)
                .overlay(
                    alignment: .top,
                    content: {
                        Rectangle()
                            .fill(theme.colors.border)
                            .frame(height: 1)
                    }
                )
                .transition(.blurReplace.animation(.default))
        } else {
            EmptyView()
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
