//
//  OTPFieldView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI

struct OTPFieldView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var code: String
    let numberOfInputs: Int = 6
    
    @FocusState private var isFocused: Bool
    @State private var cursorAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfInputs, id: \.self) { index in
                otpFieldInput(index: index)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .overlay {
            TextField("", text: $code.maxLength(numberOfInputs))
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.clear)
                .tint(.clear)
                .focused($isFocused)
        }
        .contentShape(Rectangle())
        .task { isFocused = true }
    }
    
    @ViewBuilder 
    func otpFieldInput(index: Int) -> some View {
        var isSelected: Bool {
            isFocused && code.count == index
        }
                
        VStack(spacing: 12) {
            ZStack {
                if code.count > index {
                    let startIndex = code.startIndex
                    let charIndex = code.index(startIndex, offsetBy: index)
                    let charToString = String(code[charIndex])
                    Text(charToString)
                } else {
                    Text(" ")
                }
            }
            .font(.title3.weight(.bold))
            .foregroundStyle(clerkTheme.colors.textPrimary)
            .overlay {
                if isSelected {
                    Rectangle()
                        .frame(width: 2, height: 17)
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                        .opacity(cursorAnimating ? 1 : 0)
                        .animation(.easeInOut.speed(0.75).repeatForever(), value: cursorAnimating)
                        .onAppear {
                            cursorAnimating.toggle()
                        }
                }
            }
        }
        .frame(minWidth: 40, minHeight: 40)
        .allowsHitTesting(false)
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(clerkTheme.colors.borderPrimary)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(.lightGray), lineWidth: 4)
            }
        }
    }
}

private extension Binding where Value == String {
    func maxLength(_ length: Int) -> Self {
        if wrappedValue.count > length {
            DispatchQueue.main.async {
                self.wrappedValue = String(wrappedValue.prefix(6))
            }
        }
        return self
    }
}

#Preview {
    OTPFieldView(code: .constant(""))
        .padding()
}

#endif
