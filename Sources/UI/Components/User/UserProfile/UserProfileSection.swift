//
//  UserProfileSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import NukeUI

struct UserProfileSection: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var updateProfileIsPresented = false
    
    private var user: User? {
        clerk.client?.lastActiveSession?.user
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.footnote.weight(.medium))
            
            if let user {
                HStack {
                    UserPreviewView(user: user, hideSubtitle: true)
                    Spacer()
                    #if !os(tvOS)
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
                    #endif
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
