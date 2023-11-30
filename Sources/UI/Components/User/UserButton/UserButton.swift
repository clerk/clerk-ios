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
    
    @State private var popoverIsPresented = false
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            userButtonAction()
        }, label: {
            LazyImage(
                url: URL(string: clerk.client.lastActiveSession?.user?.imageUrl ?? ""),
                transaction: .init(animation: .default)
            ) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
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
        .onChange(of: clerk.client.lastActiveSession?.user) { user in
            if user == nil { popoverIsPresented = false }
        }
        .popover(isPresented: $popoverIsPresented, content: {
            UserButtonPopover()
                .presentationDetents([.medium, .large])
        })
    }
    
    private func userButtonAction() {
        if clerk.client.lastActiveSession?.user != nil {
            popoverIsPresented = true
        } else {
            clerkUIState.presentedAuthStep = .signInStart
        }
    }
}

#Preview {
    UserButton()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
