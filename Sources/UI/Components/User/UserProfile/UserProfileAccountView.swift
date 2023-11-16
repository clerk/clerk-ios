//
//  UserProfileAccountView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

public struct UserProfileAccountView: View {
    @EnvironmentObject private var clerk: Clerk
    @State private var didFetchClient = false
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                HeaderView(
                    title: "Account",
                    subtitle: "Manage your account information"
                )
                
                UserProfileSection()
                UserProfileEmailSection()
                UserProfilePhoneNumberSection()
                UserProfileExternalAccountSection()
            }
            .padding(30)
            .animation(.snappy, value: user)
        }
        .task {
            if !didFetchClient {
                try? await clerk.client.get()
                didFetchClient = true
            }
        }
    }
}

#Preview {
    _ = Container.shared.clerk.register { .mock }
    return UserProfileAccountView()
        .environmentObject(Clerk.mock)
}

#endif
