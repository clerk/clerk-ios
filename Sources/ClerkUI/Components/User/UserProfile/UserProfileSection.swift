//
//  UserProfileSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if os(iOS)

import SwiftUI

struct UserProfileSection: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkTheme.self) private var clerkTheme
    @State private var updateProfileIsPresented = false
    
    private var user: User? {
        clerk.user
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.footnote.weight(.medium))
            
            if let user {
                HStack {
                    UserPreviewView(user: user, hideSubtitle: true)
                    Spacer()
                    Button {
                        updateProfileIsPresented = true
                    } label: {
                        Text("Edit profile")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $updateProfileIsPresented) {
                        UserProfileUpdateProfileView()
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
            
            Divider()
        }
        .animation(.snappy, value: user)
    }
}

#Preview {
    UserProfileSection()
        .padding()
}

#endif
