//
//  SignInExampleView.swift
//
//
//  Created by Mike Pitre on 10/6/23.
//

import SwiftUI
import Clerk

struct SignInExampleView: View {
    @EnvironmentObject private var clerk: Clerk
    
    var body: some View {
        Button {
            clerk.signInIsPresented = true
        } label: {
            Text("Sign In!")
        }
        .buttonStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SignInExampleView()
}
