//
//  UserButton.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

public struct UserButton: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) var clerkTheme
    
    @State private var profileIsPresented = false
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            userButtonAction()
        }, label: {
            AsyncImage(
                url: URL(string: clerk.client.lastActiveSession?.user.imageUrl ?? ""),
                transaction: Transaction(animation: .bouncy))
            { phase in
                switch phase {
                case .empty:
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                        .tint(clerkTheme.colors.primary)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                        .tint(clerkTheme.colors.primary)
                @unknown default:
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                        .tint(clerkTheme.colors.primary)
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
        if let lastSession = clerk.client.lastActiveSession {
            profileIsPresented = true
        } else {
            clerk.signInIsPresented = true
        }
    }
}

#Preview {
    UserButton()
        .environmentObject(Clerk.mock)
}

#endif
