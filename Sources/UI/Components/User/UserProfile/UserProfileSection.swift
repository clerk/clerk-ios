//
//  UserProfileSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

struct UserProfileSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var updateProfileIsPresented = false
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
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
        .environmentObject(Clerk.mock)
}

#endif
