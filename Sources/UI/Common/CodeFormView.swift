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
    @State private var isSubmittingCode: Bool = false
    
    @Binding var code: String
    let title: String
    let subtitle: String
    var onCodeEntry: (() async -> Void)?
    var onResend: (() async -> Void)?
    
    private let requiredOtpCodeLength = 6
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 8)
            
            Text(subtitle)
                .fixedSize(horizontal: false, vertical: true)
                .font(.footnote.weight(.light))
                .foregroundStyle(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 20) {
                OTPFieldView(code: $code)
                    .frame(maxWidth: 250)
                    .padding(.vertical)
                    .padding(.bottom)
                
                if isSubmittingCode {
                    ProgressView()
                        .offset(y: 4)
                }
            }
            .onChange(of: code) { newValue in
                if newValue.count == requiredOtpCodeLength {
                    Task {
                        isSubmittingCode = true
                        await onCodeEntry?()
                        isSubmittingCode = false
                    }
                }
            }
            
            AsyncButton(options: [.disableButton], action: {
                Task { await onResend?() }
            }, label: {
                Text("Didn't recieve a code? Resend")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(clerkTheme.colors.primary)
            })
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
    CodeFormView(
        code: .constant(""),
        title: "Verification code",
        subtitle: "Enter the verification code sent to your email address"
    )
}

#endif
