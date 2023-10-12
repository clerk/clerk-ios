//
//  SignInViewModifier.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if !os(macOS)

import Foundation
import SwiftUI

public struct SignInViewModifier: ViewModifier, KeyboardReadable {
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var isPresented: Bool
    var presentationStyle: ClerkTheme.SignIn.PresentationStyle = .sheet
    
    @State private var geoSize: CGSize = UIScreen.main.bounds.size
    @GestureState private var gestureState: CGSize = .zero
    @State private var keyboardShowing = false
    
    private var modalDismissThreshold: CGFloat { geoSize.height / 2 }
    private var backgroundOpacity: CGFloat { 1 - (gestureState.height / modalDismissThreshold) }
        
    public func body(content: Content) -> some View {
        Group {
            switch presentationStyle {
            case .sheet: sheetStyle(content: content)
            case .modal: modalStyle(content: content)
            }
        }
        .onReceive(keyboardPublisher, perform: { showing in
            keyboardShowing = showing
        })
        
    }
    
    @ViewBuilder
    private func sheetStyle(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, content: {
                ScrollView {
                    SignInView()
                        .interactiveDismissDisabled(keyboardShowing)
                }
            })
            // hack to get toolbar to show within sheet
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .keyboard) {
                        HStack {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
    }
    
    @ViewBuilder
    private func modalStyle(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                Color.clear
                    .background {
                        clerkTheme.signIn.modalBackground
                            .opacity(backgroundOpacity)
                            .animation(.default, value: backgroundOpacity)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut))
            }
            
            ZStack {
                if isPresented {
                    GeometryReader { geo in
                        ScrollView {
                            ZStack(alignment: .top) {
                                Color(.systemBackground).opacity(0.001)
                                    .blendMode(.screen)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .onTapGesture {
                                        isPresented = false
                                    }
                                
                                SignInView()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                                    .shadow(color: Color(.label).opacity(0.2), radius: 20)
                                    .padding()
                                    .offset(x: gestureState.width, y: gestureState.height)
                                    .animation(.bouncy, value: gestureState)
                                    .gesture(
                                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                                            .updating($gestureState, body: { value, state, transaction in
                                                if !keyboardShowing {
                                                    state = value.translation
                                                }
                                            })
                                            .onEnded({ value in
                                                if !keyboardShowing && value.predictedEndTranslation.height > modalDismissThreshold {
                                                    isPresented = false
                                                }
                                            })
                                    )
                            }
                        }
                        .scrollDisabled(!keyboardShowing)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .readSize(onChange: { geoSize = $0 })
                }
            }
            .animation(.bouncy, value: isPresented)
        }
    }
}

extension View {
    func signInView(
        isPresented: Binding<Bool>,
        presentationStyle: ClerkTheme.SignIn.PresentationStyle = .sheet
    ) -> some View {
        modifier(SignInViewModifier(
            isPresented: isPresented,
            presentationStyle: presentationStyle
        ))
    }
}

#endif
