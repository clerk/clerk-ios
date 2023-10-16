//
//  SignUpView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

extension SignUpView {
    final class Model: ObservableObject {
        
        enum SignInStep {
            case create
            case verify
        }
        
        @Published var step: SignInStep = .create
    }
}

struct SignUpView: View {
    @EnvironmentObject private var clerk: Clerk
    @StateObject private var model = Model()
    
    @Namespace private var namespace
    
    public var body: some View {
        ZStack {
            switch model.step {
            case .create:
                SignUpCreateView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            case .verify:
                EmptyView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            }
        }
        .animation(.bouncy, value: model.step)
        .environmentObject(model)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                clerk.signUpIsPresented = false
            }, label: {
                Text("Cancel")
                    .font(.caption.weight(.medium))
            })
            .padding(30)
            .tint(.primary)
        }
        .onChange(of: model.step) { _ in
            KeyboardHelpers.dismissKeyboard()
        }
    }
}

#Preview {
    SignUpView()
}

#endif
