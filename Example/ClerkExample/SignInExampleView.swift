//
//  SignInExampleView.swift
//
//
//  Created by Mike Pitre on 10/6/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInExampleView: View {
    @EnvironmentObject private var clerk: Clerk
    
    var body: some View {
        VStack {
            Button {
                clerk.presentSignIn()
            } label: {
                Text("Sign In!")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SignInExampleView_Previews: PreviewProvider {
    static var previews: some View {
        SignInExampleView()
            .environmentObject(Clerk.mock)
    }
}

#endif
