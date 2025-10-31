//
//  UserProfilePasskeySection.swift
//  Clerk
//
//  Created by Mike Pitre on 5/29/25.
//

#if os(iOS)

import SwiftUI

struct UserProfilePasskeySection: View {
    @Environment(Clerk.self) private var clerk
    @Environment(\.clerkTheme) private var theme

    @State private var error: Error?

    var user: User? {
        clerk.user
    }

    var sortedPasskeys: [Passkey] {
        guard let user else { return [] }
        return user.passkeys.sorted { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(sortedPasskeys) {
                    UserProfilePasskeyRow(passkey: $0)
                }

                UserProfileButtonRow(text: "Add a passkey") {
                    await createPasskey()
                }
            }
            .background(theme.colors.background)
        } header: {
            UserProfileSectionHeader(text: "PASSKEYS")
        }
        .clerkErrorPresenting($error)
    }
}

extension UserProfilePasskeySection {
    func createPasskey() async {
        guard let user else { return }

        do {
            try await user.createPasskey()
        } catch {
            if error.isUserCancelledError { return }
            self.error = error
            ClerkLogger.error("Failed to create passkey", error: error)
        }
    }
}

#Preview {
    UserProfilePasskeySection()
        .clerkPreviewMocks()
        .environment(\.clerkTheme, .clerk)
}

#endif
