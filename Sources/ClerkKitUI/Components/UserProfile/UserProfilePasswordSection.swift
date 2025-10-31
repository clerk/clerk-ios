//
//  UserProfilePasswordRow.swift
//  Clerk
//
//  Created by Mike Pitre on 5/12/25.
//

#if os(iOS)

import ClerkKit
import Foundation
import SwiftUI

struct UserProfilePasswordSection: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme

    enum PasswordAction: Hashable, Identifiable {
        case add, reset
        var id: Self { self }
    }

    @State private var passwordAction: PasswordAction?

    var user: User? { clerk.user }

    var body: some View {
        Section {
            Button {
                passwordAction = .reset
            } label: {
                buttonLabel
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(theme.colors.border)
            }
            .background(theme.colors.background)
            .buttonStyle(.pressedBackground)
            .simultaneousGesture(TapGesture())
        } header: {
            UserProfileSectionHeader(text: "PASSWORD")
        }
        .sheet(item: $passwordAction) { action in
            UserProfileChangePasswordView(isAddingPassword: action == .add)
        }
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if user?.passwordEnabled == true {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image("icon-lock", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(theme.colors.mutedForeground)
                    Text(verbatim: "•••••••••••••••••••••••••")
                        .font(theme.fonts.subheadline)
                        .foregroundStyle(theme.colors.mutedForeground)
                        .frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(theme.colors.border)

                UserProfileButtonRow(text: "Change password") {}
                    .disabled(true)
            }
        } else {
            UserProfileButtonRow(text: "Add password") {
                passwordAction = .add
            }
        }
    }

}

#Preview {
    UserProfilePasswordSection()
        .environment(\.clerkTheme, .clerk)
}

#endif
