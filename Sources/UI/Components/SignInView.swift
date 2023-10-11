//
//  SignInFlowContainerView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

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
                CreateSignInView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            case .firstFactor:
                FirstFactorView()
                    .matchedGeometryEffect(id: "view", in: namespace)
            }
        }
        .animation(.easeInOut, value: model.step)
        .environmentObject(model)
    }
}

#Preview {
    SignInView()
        .environmentObject(Clerk.mock)
}

public struct SignInViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    var presentationStyle: PresentationStyle = .sheet
        
    public enum PresentationStyle {
        case sheet
        case modal
    }
    
    public func body(content: Content) -> some View {
        switch presentationStyle {
        case .sheet: sheetStyle(content: content)
        case .modal: modalStyle(content: content)
        }
    }
    
    @ViewBuilder
    private func sheetStyle(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, content: {
                ScrollView {
                    SignInView()
                }
            })
    }
    
    @ViewBuilder
    private func modalStyle(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut))
            }
            
            ZStack {
                if isPresented {
                    GeometryReader { geo in
                        ScrollView {
                            ZStack(alignment: .top) {
                                Color(.systemBackground).opacity(0.001)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .foregroundStyle(.background)
                                    .onTapGesture {
                                        withAnimation(.bouncy.speed(0.75)) {
                                            isPresented = false
                                        }
                                    }
                                
                                SignInView()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                                    .shadow(color: Color(.label).opacity(0.2), radius: 20)
                                    .padding()
                            }
                        }
                    }
                    .transition(.offset(y: UIScreen.main.bounds.height))
                }
            }
            .animation(.bouncy, value: isPresented)
        }
    }
}

public extension View {
    func signInView(
        isPresented: Binding<Bool>,
        presentationStyle: SignInViewModifier.PresentationStyle = .sheet
    ) -> some View {
        modifier(SignInViewModifier(
            isPresented: isPresented,
            presentationStyle: presentationStyle
        ))
    }
}
