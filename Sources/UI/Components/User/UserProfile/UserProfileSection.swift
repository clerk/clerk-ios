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
            UserProfileSectionHeader(title: "Profile")
            
            if let user {
                Button {
                    updateProfileIsPresented = true
                } label: {
                    UserPreviewView(user: user, hideSubtitle: true)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $updateProfileIsPresented) {
                    UserProfileUpdateProfileView()
                }
            }
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
