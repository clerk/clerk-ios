//
//  SwiftUIView.swift
//  
//
//  Created by Mike Pitre on 3/13/24.
//

#if canImport(UIKit)

import SwiftUI

struct UserProfileDeleteAccountSection: View {
    @ObservedObject private var clerk = Clerk.shared
    @State private var confirmationIsPresented = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Termination")
                .font(.footnote.weight(.medium))
            
            Button(role: .destructive) {
                confirmationIsPresented = true
            } label: {
                Text("Delete Account")
                    .font(.caption.weight(.medium))
            }
            .padding(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: clerk.user)
        .animation(.snappy, value: clerk.sessionsByUserId)
        .sheet(isPresented: $confirmationIsPresented) {
            DeleteAccountConfirmationView()
        }
    }
}

#Preview {
    UserProfileDeleteAccountSection()
        .padding()
}

private struct DeleteAccountConfirmationView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @State private var confirmationText = ""
    @State private var errorWrapper: ErrorWrapper?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Delete account")
                        .font(.title2.weight(.bold))
                    Group {
                        Text("Are you sure you want to delete your account? This action is ") +
                        Text("permanent and irreversible.").foregroundColor(.red)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading) {
                    Text("Type \"Delete account\" below to continue")
                        .fontWeight(.medium)
                    CustomTextField(text: $confirmationText, placeholder: "Delete account")
                }
                .font(.footnote)
                
                VStack(spacing: 16) {
                    AsyncButton {
                        await deleteAccount()
                    } label: {
                        Text("Delete account")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkDangerButtonStyle())
                    
                    AsyncButton {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkSecondaryButtonStyle())
                }
            }
            .padding()
            .padding(.top, 30)
        }
        .dismissButtonOverlay()
        .clerkErrorPresenting($errorWrapper)
    }
    
    @MainActor
    private func deleteAccount() async {
        do {
            guard confirmationText == "Delete account" else {
                throw ClerkClientError(message: "Please type \"Delete account\" to continue.")
            }
            
            guard let user = clerk.user else {
                throw ClerkClientError(message: "Unable to determine the current user.")
            }
            
            try await user.delete()
            clerkUIState.userProfileIsPresented = false
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
}

#Preview {
    DeleteAccountConfirmationView()
}

#endif
