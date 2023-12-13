//
//  VerificationCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI

struct VerificationCodeView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    @Binding var code: String
    
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
        
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HeaderView(
                title: title,
                subtitle: subtitle
            )
            
            IdentityPreviewView(
                imageUrl: profileImageUrl,
                label: safeIdentifier,
                action: {
                    Task { await onIdentityPreviewTapped?() }
                }
            )
            
            CodeFormView(
                code: $code,
                title: formTitle,
                subtitle: formSubtitle
            )
            .onCodeEntry {
                await onCodeEntry?()
            }
            
            AsyncButton {
                await onUseAlernateMethod?()
            } label: {
                Text("Use another method")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(clerkTheme.colors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .padding(.vertical)
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
        code: .constant(""),
        title: "Check your email",
        subtitle: "to continue to Test 1",
        formTitle: "Verification code",
        formSubtitle: "Enter the verification code sent to your email address",
        safeIdentifier: "ClerkUser@clerk.dev"
    )
}

#endif
