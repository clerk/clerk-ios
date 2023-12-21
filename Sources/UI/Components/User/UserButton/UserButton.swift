//
//  UserButton.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Nuke
import NukeUI

public struct UserButton: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) var clerkTheme
    
    @State private var popoverIsPresented = false
    
    public init() {}
    
    private var imageRequest: ImageRequest {
        .init(
            url: URL(string: clerk.client.lastActiveSession?.user?.imageUrl ?? ""),
            processors: [ImageProcessors.Circle()]
        )
    }
    
    public var body: some View {
        Button(action: {
            userButtonAction()
        }, label: {
            LazyImage(request: imageRequest) { state in
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
            .clipShape(.circle)
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
