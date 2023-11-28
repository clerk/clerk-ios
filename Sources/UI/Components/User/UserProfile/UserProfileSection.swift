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
            
            Button {
                updateProfileIsPresented = true
            } label: {
                HStack(spacing: 16) {
                    if let imageUrl = user?.imageUrl {
                        LazyImage(url: URL(string: imageUrl)) { imageState in
                            if let image = imageState.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color(.secondarySystemBackground)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(.circle)
                    }
                    
                    if let fullName = user?.fullName {
                        Text(fullName)
                            .font(.footnote)
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $updateProfileIsPresented) {
                UserProfileUpdateProfileView()
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
