//
//  UserButton.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if os(iOS)

import SwiftUI
import Nuke
import NukeUI

public struct UserButton: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) var clerkTheme
    
    @State private var popoverIsPresented = false
    
    public init() {}
    
    private var imageRequest: ImageRequest {
        .init(
            url: URL(string: clerk.client?.lastActiveSession?.user?.imageUrl ?? ""),
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
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.monochrome)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(.circle)
        })
        .tint(clerkTheme.colors.textPrimary)
        .onChange(of: clerk.client?.lastActiveSession?.user) { user in
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
        .environmentObject(ClerkUIState())
}

#endif
