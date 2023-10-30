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
    
    @Binding var otpCode: String
    let numberOfInputs: Int = 6
    
    @FocusState private var isKeyboardShowing: Bool
    @State var cursorAnimating = false
    
    var body: some View {
        HStack {
            ForEach(0..<numberOfInputs, id: \.self) { index in
                otpFieldInput(index: index)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .overlay {
            TextField("", text: $otpCode.maxLength(numberOfInputs))
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.clear)
                .tint(.clear)
                .focused($isKeyboardShowing)
        }
        .contentShape(Rectangle())
        .onAppear {
            isKeyboardShowing = true
        }
    }
    
    @ViewBuilder 
    func otpFieldInput(index: Int) -> some View {
        var isSelected: Bool {
            isKeyboardShowing && otpCode.count == index
        }
                
        VStack(spacing: 12) {
            ZStack {
                if otpCode.count > index {
                    let startIndex = otpCode.startIndex
                    let charIndex = otpCode.index(startIndex, offsetBy: index)
                    let charToString = String(otpCode[charIndex])
                    Text(charToString)
                } else {
                    Text(" ")
                }
            }
            .font(.title2.weight(.semibold))
            .overlay {
                if isSelected {
                    Rectangle()
                        .frame(width: 2, height: 28)
                        .foregroundStyle(clerkTheme.colors.primary)
                        .opacity(cursorAnimating ? 1 : 0)
                        .animation(.easeInOut.speed(0.75).repeatForever(), value: cursorAnimating)
                        .onAppear {
                            cursorAnimating.toggle()
                        }
                }
            }
            
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(isSelected ? clerkTheme.colors.primary : Color(.systemFill))
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
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
    OTPFieldView(otpCode: .constant(""))
        .padding()
}

#endif
