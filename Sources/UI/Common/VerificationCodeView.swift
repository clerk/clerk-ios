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
    @State private var isSubmittingCode: Bool = false
    
    let title: String
    let subtitle: String
    var safeIdentifier: String?
    var profileImageUrl: String?
    
    var onCodeEntry: (() async -> Void)?
    var onResend: (() async -> Void)?
    var onIdentityPreviewTapped: (() async -> Void)?
    var onUseAlernateMethod: (() async -> Void)?
    var onContinueAction: (() async -> Void)?
    var onCancel: (() async -> Void)?
    
    var body: some View {
        VStack {
            VStack(spacing: .zero) {
                HeaderView(
                    title: title,
                    subtitle: subtitle
                )
                .padding(.bottom, 4)
                
                IdentityPreviewView(
                    label: safeIdentifier,
                    action: onIdentityPreviewTapped == nil ? nil : { Task { await onIdentityPreviewTapped?() }}
                )
            }
            
            CodeFormView(
                code: $code,
                isSubmittingCode: $isSubmittingCode,
                onCodeEntry: onCodeEntry == nil ? nil : { await onCodeEntry?() },
                onResend: onResend == nil ? nil : { await onResend?() }
            )
            .padding(.bottom, 32)
            
            if let onContinueAction {
                AsyncButton {
                    await onContinueAction()
                } label: {
                    Text("Continue")
                        .opacity(isSubmittingCode ? 0 : 1)
                        .overlay {
                            if isSubmittingCode {
                                ProgressView()
                            }
                        }
                        .animation(.snappy, value: isSubmittingCode)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
                .padding(.bottom, 18)
            }
            
            if let onUseAlernateMethod {
                AsyncButton {
                    await onUseAlernateMethod()
                } label: {
                    Text("Use another method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                }
            }
        }
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
    
    func onContinueAction(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onContinueAction = action
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
        subtitle: "Enter the verification code sent to your email address",
        safeIdentifier: "ClerkUser@clerk.dev"
    )
    .onContinueAction {
        //
    }
    .onUseAlernateMethod {
        //
    }
    .padding()
}

#endif
