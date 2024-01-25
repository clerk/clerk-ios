//
//  UserProfileMFASelectPhoneView.swift
//
//
//  Created by Mike Pitre on 1/25/24.
//

import SwiftUI
import Clerk

struct UserProfileMFASelectPhoneView: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    @State private var addPhoneNumberPresented = false
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? { clerk.user }
    private var availablePhoneNumbers: [PhoneNumber] {
        user?.phoneNumbersAvailableForSecondFactor ?? []
    }
    
    private func reserveForSecondFactor(phoneNumber: PhoneNumber) async {
        do {
            try await phoneNumber.setReservedForSecondFactor()
            dismiss()
        } catch {
            errorWrapper = .init(error: error)
        }
    }
    
    var body: some View {
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
        .clerkErrorPresenting($errorWrapper)
        .dismissButtonOverlay()
    }
}

#Preview {
    UserProfileMFASelectPhoneView()
        .environmentObject(Clerk.mock)
}
