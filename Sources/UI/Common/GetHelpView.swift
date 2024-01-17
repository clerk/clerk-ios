//
//  GetHelpView.swift
//
//
//  Created by Mike Pitre on 1/17/24.
//

import SwiftUI

struct GetHelpView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var title = "Get Help"
    var description = "If you’re experiencing difficulty signing into your account, email us and we will work with you to restore access as soon as possible."
    var primaryButtonConfig: ButtonConfig?
    var secondaryButtonConfig: ButtonConfig?
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.body.weight(.bold))
                        .frame(minHeight: 24)
                    Text(description)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }
                .padding(.bottom, 32)
                
                VStack(spacing: 12) {
                    if let primaryButtonConfig, let label = primaryButtonConfig.label {
                        Button {
                            primaryButtonConfig.action?()
                        } label: {
                            Text(label)
                                .clerkStandardButtonPadding()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClerkPrimaryButtonStyle())
                    }

                    if let secondaryButtonConfig, let label = secondaryButtonConfig.label {
                        Button {
                            secondaryButtonConfig.action?()
                        } label: {
                            Text(label)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(clerkTheme.colors.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                    }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal)
        }
    }
}

#Preview {
    GetHelpView(
        primaryButtonConfig: .init(label: "Email support", action: {}),
        secondaryButtonConfig: .init(label: "Back to sign in", action: {}))
}
