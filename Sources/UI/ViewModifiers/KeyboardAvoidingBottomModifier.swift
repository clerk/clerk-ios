//
//  KeyboardAvoidingBottomModifier.swift
//
//
//  Created by Mike Pitre on 12/20/23.
//

import SwiftUI

struct KeyboardAvoidingBottomModifier<BottomView: View>: ViewModifier {
    @State private var bottomViewSize: CGSize?
    @Environment(\.keyboardShowing) private var keyboardShowing
    
    @ViewBuilder var bottomView: BottomView
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .padding(.bottom, keyboardShowing ? 0 : bottomViewSize?.height ?? 0)

            VStack {
                Spacer()
                bottomView
                    .readSize { bottomViewSize = $0 }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

extension View {
    func keyboardAvoidingBottomView<BottomView: View>(content: () -> BottomView) -> some View {
        modifier(KeyboardAvoidingBottomModifier(bottomView: content))
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
