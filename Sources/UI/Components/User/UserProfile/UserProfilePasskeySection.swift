//
//  UserProfilePasskeySection.swift
//
//
//  Created by Mike Pitre on 9/6/24.
//

#if os(iOS)

import SwiftUI

struct UserProfilePasskeySection: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    
    private var user: User? {
        clerk.client?.lastActiveSession?.user
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Passkeys")
                .font(.footnote.weight(.medium))
            
            Button(action: {
                Task { await createPasskey() }
            }, label: {
                Text("+ Add a passkey")
                    .font(.caption.weight(.medium))
                    .frame(minHeight: 32)
                    .tint(clerkTheme.colors.textPrimary)
            })
            .padding(.leading, 12)
            
            Divider()
        }
    }
}

extension UserProfilePasskeySection {
    
    @MainActor
    func createPasskey() async {
        guard let user else { return }
        
        do {
            try await user.createPasskey()
        } catch {
            dump(error)
        }
    }
    
}

#Preview {
    UserProfilePasskeySection()
}

#endif
