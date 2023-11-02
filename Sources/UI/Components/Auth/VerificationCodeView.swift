//
//  VerificationCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

import SwiftUI

struct VerificationCodeView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var isSubmittingCode: Bool = false
    
    @Binding var otpCode: String
    
    let title: String
    let subtitle: String
    let formTitle: String
    let formSubtitle: String
    let safeIdentifier: String?
    var profileImageUrl: String?
    
    var onCodeEntry: (() async -> Void)?
    var onResend: (() async -> Void)?
    var onIdentityPreviewTapped: (() async -> Void)?
    var onUseAlernateMethod: (() async -> Void)?
    var onCancel: (() async -> Void)?
    
    private let requiredOtpCodeLength = 6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 6) {
                Image("clerk-logomark", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("clerk")
                    .font(.title3.weight(.semibold))
            }
            .font(.title3.weight(.medium))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            IdentityPreviewView(
                imageUrl: profileImageUrl,
                label: safeIdentifier,
                action: {
                    Task { await onIdentityPreviewTapped?() }
                }
            )
            
            VStack(alignment: .leading) {
                Text(formTitle)
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 8)
                
                Text(formSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.footnote.weight(.light))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    OTPFieldView(otpCode: $otpCode)
                        .frame(maxWidth: 250)
                        .padding(.vertical)
                        .padding(.bottom)
                    
                    if isSubmittingCode {
                        ProgressView()
                            .offset(y: 4)
                    }
                }
                .onChange(of: otpCode) { newValue in
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
                        .font(.subheadline)
                        .foregroundStyle(clerkTheme.colors.primary)
                })
            }
            
            AsyncButton(action: {
                await onUseAlernateMethod?()
            }, label: {
                Text("Use another method")
                    .font(.subheadline)
                    .foregroundStyle(clerkTheme.colors.primary)
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
        .background(.background)
    }
}

extension VerificationCodeView {
    
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
    
    func onIdentityPreviewTapped(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onIdentityPreviewTapped = action
        return copy
    }
    
    func onUseAlernateMethod(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onUseAlernateMethod = action
        return copy
    }
    
    func onCancel(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onCancel = action
        return copy
    }
    
}

#Preview {
    VerificationCodeView(
        otpCode: .constant(""),
        title: "Check your email",
        subtitle: "to continue to Test 1",
        formTitle: "Verification code",
        formSubtitle: "Enter the verification code sent to your email address",
        safeIdentifier: "ClerkUser@clerk.dev"
    )
}
