//
//  UserButton.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if os(iOS)

import SwiftUI
import Clerk
import Kingfisher

public struct UserButton: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(ClerkTheme.self) private var clerkTheme
    
    @State private var popoverIsPresented = false
    
    public init() {}
        
    public var body: some View {
        Button(action: {
            userButtonAction()
        }, label: {
            KFImage(URL(string: clerk.user?.imageUrl ?? ""))
                .resizable()
                .placeholder {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                }
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(.circle)
        })
        .tint(clerkTheme.colors.textPrimary)
        .onChange(of: clerk.client?.lastActiveSession?.user) { _, user in
            if user == nil { popoverIsPresented = false }
        }
        .popover(isPresented: $popoverIsPresented, content: {
            UserButtonPopover()
                .presentationDetents([.medium, .large])
        })
    }
    
    private func userButtonAction() {
        if clerk.user != nil {
            popoverIsPresented = true
        } else {
            clerkUIState.presentedAuthStep = .signInStart
        }
    }
}

#Preview {
    UserButton()
        .environment(ClerkUIState())
}

#endif
