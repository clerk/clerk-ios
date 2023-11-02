//
//  UserButton.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

public struct UserButton: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) var clerkTheme
    
    @State private var profileIsPresented = false
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            userButtonAction()
        }, label: {
            LazyImage(
                url: URL(string: clerk.client.lastActiveSession?.user.imageUrl ?? ""),
                transaction: Transaction(animation: .default)
            ) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                        .tint(clerkTheme.colors.primary) // Acts as a placeholder
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        })
        .sheet(isPresented: $profileIsPresented, content: {
            Text("Profile goes here.")
        })
    }
    
    private func userButtonAction() {
        if clerk.client.lastActiveSession != nil {
            profileIsPresented = true
        } else {
            clerkUIState.presentedAuthStep = .signInStart
        }
    }
}

#Preview {
    UserButton()
        .environmentObject(Clerk.mock)
}

#endif
