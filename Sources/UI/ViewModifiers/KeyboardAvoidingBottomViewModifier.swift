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
    func keyboardAvoidingBottomView<BottomView: View>(@ViewBuilder content: () -> BottomView) -> some View {
        modifier(KeyboardAvoidingBottomViewModifier(bottomView: content))
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
