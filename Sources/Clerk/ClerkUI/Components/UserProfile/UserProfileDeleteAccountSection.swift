//
//  UserProfileDeleteAccountSection.swift
//  Clerk
//
//  Created by Mike Pitre on 5/13/25.
//

#if os(iOS)

import SwiftUI

struct UserProfileDeleteAccountSection: View {
    @Environment(\.clerkTheme) private var theme

    @State private var confirmationIsPresented = false

    var body: some View {
        Section {
            UserProfileButtonRow(text: "Delete account", style: .danger) {
                confirmationIsPresented = true
            }
            .background(theme.colors.background)
        } header: {
            UserProfileSectionHeader(text: "DELETE ACCOUNT")
        }
        .sheet(isPresented: $confirmationIsPresented) {
            UserProfileDeleteAccountConfirmationView()
        }
    }
}

#Preview {
    UserProfileDeleteAccountSection()
}

#endif
