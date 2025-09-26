//
//  UserPreviewView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

@_spi(Internal) import ClerkKit
import NukeUI
import SwiftUI

struct UserPreviewView: View {
    @Environment(\.clerkTheme) private var theme

    let user: User

    var body: some View {
        HStack(spacing: 16) {
            LazyImage(url: URL(string: user.imageUrl)) { state in
                avatar(for: state)
            }
            .frame(width: 48, height: 48)
            .clipShape(.circle)

            VStack(alignment: .leading, spacing: 4) {
                if let fullName = user.fullName {
                    Text(fullName)
                        .font(theme.fonts.body)
                        .foregroundStyle(theme.colors.foreground)
                        .frame(minHeight: 22)
                }

                if let identifier = user.identifier {
                    Text(identifier)
                        .font(
                            user.fullName == nil
                                ? theme.fonts.body
                                : theme.fonts.subheadline
                        )
                        .foregroundStyle(
                            user.fullName == nil
                                ? theme.colors.foreground
                                : theme.colors.mutedForeground
                        )
                }
            }
        }
    }
}

extension UserPreviewView {

    @ViewBuilder
    private func avatar(for state: LazyImageState) -> some View {
        if let image = state.image {
            image
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(theme.colors.primary.gradient)
        }
    }
}

#Preview {
    UserPreviewView(user: .mock)
        .environment(\.clerkTheme, .clerk)
}

#endif
