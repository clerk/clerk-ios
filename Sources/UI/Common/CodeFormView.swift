//
//  CodeFormView.swift
//
//
//  Created by Mike Pitre on 11/6/23.
//

#if canImport(UIKit)

import SwiftUI

struct CodeFormView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var code: String
    @Binding var isSubmittingCode: Bool
    var onCodeEntry: (() async -> Void)?
    var onResend: (() async -> Void)?
    
    private let requiredOtpCodeLength = 6
    
    var body: some View {
        VStack(spacing: 12) {
            OTPFieldView(code: $code)
                .frame(maxWidth: 250)
                .padding(.vertical)
                .onChange(of: code) { newValue in
                    if newValue.count == requiredOtpCodeLength {
                        Task {
                            isSubmittingCode = true
                            await onCodeEntry?()
                            isSubmittingCode = false
                        }
                    }
                }
            
            if let onResend {
                AsyncButton {
                    await onResend()
                } label: {
                    HStack(spacing: 4) {
                        Text("Didn't recieve a code?")
                            .foregroundStyle(clerkTheme.colors.textSecondary)
                        Text("Resend")
                            .foregroundStyle(.foreground)
                    }
                    .font(.footnote)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension CodeFormView {
    
    func onCodeEntry(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onCodeEntry = action
        return copy
    }
    
    func onResend(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onResend = action
        return copy
    }
    
}

#Preview {
    CodeFormView(code: .constant(""), isSubmittingCode: .constant(true))
}

#endif
