//
//  UserProfileRowView.swift
//  Clerk
//
//  Created by Mike Pitre on 5/6/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileRowView: View {
    @Environment(\.clerkTheme) private var theme

    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            Image(icon, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 24)
                .foregroundStyle(theme.colors.mutedForeground)
            Text(text, bundle: .module)
                .font(theme.fonts.body)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.foreground)
                .frame(minHeight: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .contentShape(.rect)
    }
}

#Preview {
    UserProfileRowView(icon: "icon-switch", text: "Switch account")
}

#endif
