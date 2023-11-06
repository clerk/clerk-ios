//
//  UserProfileDeleteEmailView.swift
//
//
//  Created by Mike Pitre on 11/6/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct UserProfileDeleteEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    let emailAddress: EmailAddress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remove email address")
                .font(.title2.weight(.bold))
                .padding(.bottom)
            Text("\(emailAddress.emailAddress) will be removed from this account.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Text("You will no longer be able to sign in using this email address.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("CANCEL")
                        .foregroundStyle(clerkTheme.colors.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .font(.caption.weight(.bold))
                }
                
                AsyncButton(options: [.disableButton, .showProgressView], action: {
                    await delete(emailAddress: emailAddress)
                }, label: {
                    Text("REMOVE")
                        .foregroundStyle(.white)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.red, in: .rect(cornerRadius: 6, style: .continuous))
                })
            }
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    private func delete(emailAddress: EmailAddress) async {
        do {
            try await emailAddress.delete()
            dismiss()
        } catch {
            dump(error)
        }
    }
}

#Preview {
    UserProfileDeleteEmailView(emailAddress: .init(
        id: "123",
        emailAddress: "ClerkUser@clerk.dev"
    ))
}

#endif
