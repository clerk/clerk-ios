//
//  SignInView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if !os(macOS)

import SwiftUI

extension SignInView {
    final class Model: ObservableObject {
        
        enum SignInStep {
            case create
            case firstFactor
        }
        
        @Published var step: SignInStep = .create
    }
}

public struct SignInView: View {
    @StateObject private var model = Model()
    
    @Namespace private var namespace
    
    public var body: some View {
        ZStack {
            switch model.step {
            case .create:
                SignInCreateView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            case .firstFactor:
                SignInFirstFactorView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            }
        }
        .animation(.bouncy, value: model.step)
        .environmentObject(model)
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
    }
}

#endif
