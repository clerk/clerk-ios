//
//  KeyboardAvoidingBottomModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI

struct KeyboardIgnoringBottomViewModifier<BottomView: View>: ViewModifier, KeyboardReadable {
    @State private var bottomViewSize: CGSize = .zero
    @State private var keyboardIsVisible: Bool = false
    
    var inFrontOfContent: Bool = true
    @ViewBuilder var bottomView: BottomView
    
    func body(content: Content) -> some View {
        ZStack {
            if !inFrontOfContent {
                VStack {
                    Spacer()
                    bottomView
                        .readSize { bottomViewSize = $0 }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            
            content
                .onReceive(keyboardPublisher) { keyboardIsVisible in
                    self.keyboardIsVisible = keyboardIsVisible
                }
                .padding(.bottom, keyboardIsVisible ? 0 : bottomViewSize.height)

            if inFrontOfContent {
                VStack {
                    Spacer()
                    bottomView
                        .readSize { bottomViewSize = $0 }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }
}

extension View {
    func keyboardIgnoringBottomView<BottomView: View>(inFrontOfContent: Bool = true, @ViewBuilder content: () -> BottomView) -> some View {
        modifier(KeyboardIgnoringBottomViewModifier(inFrontOfContent: inFrontOfContent, bottomView: content))
    }
}

#Preview {
    ScrollView {
        TextField("Text Field", text: .constant("Text"))
    }
    .keyboardIgnoringBottomView {
        SecuredByClerkView()
    }
}
