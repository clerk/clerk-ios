//
//  KeyboardAvoidingBottomModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI

struct KeyboardAvoidingBottomViewModifier<BottomView: View>: ViewModifier {
    @State private var bottomViewSize: CGSize?
    @Environment(\.keyboardShowing) private var keyboardShowing
    
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
                .padding(.bottom, keyboardShowing ? 0 : bottomViewSize?.height ?? 0)

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
    func keyboardAvoidingBottomView<BottomView: View>(inFrontOfContent: Bool = true, @ViewBuilder content: () -> BottomView) -> some View {
        modifier(KeyboardAvoidingBottomViewModifier(inFrontOfContent: inFrontOfContent, bottomView: content))
    }
}

#Preview {
    ScrollView {
        TextField("Text Field", text: .constant("Text"))
    }
    .keyboardAvoidingBottomView {
        SecuredByClerkView()
    }
}
