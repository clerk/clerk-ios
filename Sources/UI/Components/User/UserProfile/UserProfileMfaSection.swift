//
//  UserProfileMfaSection.swift
//
//
//  Created by Mike Pitre on 1/24/24.
//

#if canImport(SwiftUI)

import SwiftUI

struct UserProfileMfaSection: View {
    @ObservedObject private var clerk = Clerk.shared
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var phoneNumberIsPresented: Bool = false
    @State private var authenticationAppIsPresented: Bool = false
    @State private var errorWrapper: ErrorWrapper?
    @Namespace private var namespace
    
    private var user: User? {
        clerk.user
    }
    
    private var secondFactors: [Clerk.Environment.UserSettings.Attribute: Clerk.Environment.UserSettings.AttributesConfig] {
        clerk.environment?.userSettings.secondFactorAttributes ?? [:]
    }
    
    private var showTotp: Bool  {
        secondFactors.contains(where: { $0.key == .authenticatorApp }) && user?.totpEnabled == true
    }
    
    private var showBackupCode: Bool {
        secondFactors.contains(where: { $0.key == .backupCode }) && user?.backupCodeEnabled == true
    }
    
    private func removeTOTPAsSecondFactor() async {
        do {
            try await user?.disableTOTP()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
    
    private func removePhoneAsSecondFactor(_ phoneNumber: PhoneNumber) async {
        do {
            try await phoneNumber.setReservedForSecondFactor(reserved: false)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
        
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Two-step verification")
                .font(.footnote.weight(.medium))
                .frame(minHeight: 32)
            
            if showTotp {
                totpView
                    .padding(.leading, 12)
            }
            
            if let user, !user.mfaPhones.isEmpty {
                VStack {
                    ForEach(user.mfaPhones) { phoneNumber in
                        mfaPhoneView(phoneNumber)
                    }
                }
                .padding(.leading, 12)
            }
            
            if showBackupCode {
                mfaBackupCodesView
                    .padding(.leading, 12)
            }
            
            if let user, !user.availableSecondFactors.isEmpty {
                #if !os(tvOS)
                Menu {
                    if user.availableSecondFactors.contains(where: { $0.key == .phoneNumber }) {
                        Button {
                            phoneNumberIsPresented = true
                        } label: {
                            Label("Add SMS code", systemImage: "smartphone")
                        }
                    }
                    
                    if user.availableSecondFactors.contains(where: { $0.key == .authenticatorApp }) {
                        Button {
                            authenticationAppIsPresented = true
                        } label: {
                            Label("Add authenticator application", systemImage: "lock.iphone")
                        }
                    }
                } label: {
                    Text("+ Add two-step verification")
                        .font(.caption.weight(.medium))
                        .tint(clerkTheme.colors.textPrimary)
                        .frame(minHeight: 32)
                }
                .padding(.leading, 12)
                #endif
            }
            
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: user)
        .sheet(isPresented: $phoneNumberIsPresented, content: {
            UserProfileMfaAddSmsView()
                .presentationDragIndicator(.visible)
        })
        .sheet(isPresented: $authenticationAppIsPresented, content: {
            UserProfileMfaAddTotpView()
                .presentationDragIndicator(.visible)
        })
    }
    
    @ViewBuilder
    private var totpView: some View {
        HStack(spacing: 8) {
            Group {
                Image(systemName: "lock.iphone")
                Text("Authenticator application")
            }
            .font(.footnote)
            
            CapsuleTag(text: "Default")
                .matchedGeometryEffect(id: "defaultTag", in: namespace)
            
            Spacer()
            
            #if !os(tvOS)
            Menu {
                AsyncButton(role: .destructive) {
                    await removeTOTPAsSecondFactor()
                } label: {
                    Text("Remove authenticator application")
                }
            } label: {
                MoreActionsView()
            }
            .tint(clerkTheme.colors.textPrimary)
            #endif
        }
    }
    
    @ViewBuilder
    private func mfaPhoneView(_ phoneNumber: PhoneNumber) -> some View {
        HStack(spacing: 8) {
            Group {
                Image(systemName: "circle.filled.iphone.fill")
                Text("SMS Code")
                Text(phoneNumber.formatted(.national))
            }
            .font(.footnote)
            
            if phoneNumber.defaultSecondFactor && !showTotp {
                CapsuleTag(text: "Default")
                    .matchedGeometryEffect(id: "defaultTag", in: namespace)
            }
            
            Spacer()
            
            #if !os(tvOS)
            Menu {
                AsyncButton(role: .destructive) {
                    await removePhoneAsSecondFactor(phoneNumber)
                } label: {
                    Text("Remove phone number")
                }
            } label: {
                MoreActionsView()
            }
            .tint(clerkTheme.colors.textPrimary)
            #endif
        }
    }
    
    @ViewBuilder
    private var mfaBackupCodesView: some View {
        HStack(spacing: 8) {
            Group {
                Image(systemName: "ellipsis.circle.fill")
                Text("Backup codes")
            }
            .font(.footnote)
            Spacer()
            #if !os(tvOS)
            Menu {
                Button {
                    // regenerate codes
                } label: {
                    Text("Regenerate codes")
                }
            } label: {
                MoreActionsView()
            }
            #endif
        }
        .tint(clerkTheme.colors.textPrimary)
    }
}

#Preview {
    UserProfileMfaSection()
        .padding()
}

#endif
