//
//  UserProfileMfaAddSmsView.swift
//
//
//  Created by Mike Pitre on 1/25/24.
//

import SwiftUI
import ClerkSDK

struct UserProfileMfaAddSmsView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var addPhoneNumberPresented = false
    @State private var errorWrapper: ErrorWrapper?
    @State private var backupCodes: [String]? = nil
    
    private var user: User? { clerk.user }
    private var availablePhoneNumbers: [PhoneNumber] {
        user?.phoneNumbersAvailableForSecondFactor ?? []
    }
    
    private func reserveForSecondFactor(phoneNumber: PhoneNumber) async {
        do {
            let phoneNumber = try await phoneNumber.setReservedForSecondFactor()
            self.backupCodes = phoneNumber.backupCodes
        } catch {
            errorWrapper = .init(error: error)
        }
    }
    
    var body: some View {
        ZStack {
            if let backupCodes {
                backupCodesView(backupCodes: backupCodes)
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            } else {
                selectPhoneNumberView
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            }
        }
        .animation(.snappy, value: backupCodes == nil)
        .clerkErrorPresenting($errorWrapper)
        .dismissButtonOverlay()
    }
    
    @ViewBuilder
    private var selectPhoneNumberView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add SMS code verification")
                        .font(.footnote.weight(.bold))
                        .frame(minHeight: 18)
                    Text("Select an existing phone number to register for SMS code two-step verification or add a new one.")
                        .font(.footnote)
                        .frame(minHeight: 18)
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                VStack(spacing: 8) {
                    ForEach(availablePhoneNumbers) { phoneNumber in
                        AsyncButton {
                            await reserveForSecondFactor(phoneNumber: phoneNumber)
                        } label: {
                            HStack(spacing: 8) {
                                if let regionId = phoneNumber.regionId {
                                    Text(regionId)
                                }
                                Text(phoneNumber.formatted(.international))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                }
                
                Button(action: {
                    addPhoneNumberPresented = true
                }, label: {
                    Text("+ Add a phone number")
                        .font(.caption.weight(.medium))
                        .frame(minHeight: 32)
                        .tint(clerkTheme.colors.textPrimary)
                })
                .sheet(isPresented: $addPhoneNumberPresented) {
                    UserProfileAddPhoneNumberView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
        }
    }
    
    @ViewBuilder
    private func backupCodesView(backupCodes: [String]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("SMS code verification enabled")
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                        .font(.footnote.weight(.medium))
                    Text("When signing in, you will need to enter a verification code sent to this phone number as an additional step.")
                        .foregroundStyle(clerkTheme.colors.textTertiary)
                        .font(.footnote)
                }
                
                UserProfileMfaBackupCodeListView(backupCodes: backupCodes)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Finish")
                    .frame(maxWidth: .infinity)
                    .clerkStandardButtonPadding()
            }
            .buttonStyle(ClerkPrimaryButtonStyle())
            .padding()
        }
    }
}

#Preview {
    UserProfileMfaAddSmsView()
        .environmentObject(Clerk.mock)
}
