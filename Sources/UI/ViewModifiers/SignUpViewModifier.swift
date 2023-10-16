//
//  SignUpViewModifier.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignUpViewModifier: ViewModifier, KeyboardReadable {
    @Environment(\.clerkTheme) private var clerkTheme
    @Binding var isPresented: Bool
    
    @State private var keyboardShowing = false
    
    func body(content: Content) -> some View {
        Group {
            switch clerkTheme.signUp.presentationStyle {
            case .sheet: sheetStyle(content: content)
            case .fullScreenCover: fullScreenCoverStyle(content: content)
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
                    SignUpView()
                        .interactiveDismissDisabled(keyboardShowing)
                        .presentationDragIndicator(.visible)
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
    private func fullScreenCoverStyle(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, content: {
                ScrollView {
                    SignUpView()
                        .interactiveDismissDisabled(keyboardShowing)
                        .presentationDragIndicator(.visible)
                }
            })
            // hack to get toolbar to show within fullscreen cover
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
}

extension View {
    func signUpView(
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(SignUpViewModifier(
            isPresented: isPresented
        ))
    }
}


#Preview {
    Text("SignUp")
        .signUpView(isPresented: .constant(true))
        .environment(\.clerkTheme.signUp.presentationStyle, .fullScreenCover)
}

#endif
