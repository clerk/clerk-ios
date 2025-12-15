//
//  NoticeText.swift
//  Clerk
//
//  Created by Tom Milewski on 12/15/25.
//

#if os(iOS)

import SwiftUI

struct NoticeText: View {
    @Environment(\.clerkTheme) private var theme

    let notice: ClerkClientWarning
    var alignment: Alignment = .center

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image("icon-warning", bundle: .module)
                .resizable()
                .frame(width: 16, height: 16)
                .scaledToFit()
                .offset(y: 3)
                .accessibilityHidden(true)
            Text(notice.localizedDescription)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(theme.colors.warning)
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}

#Preview {
    NoticeText(notice: ClerkClientWarning(message: "You're signing in from a new device. We're asking for verification to keep your account secure."))
        .padding()
}

#endif
