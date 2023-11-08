//
//  RemoveResourceView.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

import SwiftUI

struct RemoveResourceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    var title: String
    var messageLine1: String
    var messageLine2: String
    var onDelete: (() async -> Void)?
        
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
                .padding(.bottom)
            Text(messageLine1)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Text(messageLine2)
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
                    await onDelete?()
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
    
    func onDelete(perform action: @escaping () async -> Void) -> Self {
        var copy = self
        copy.onDelete = action
        return copy
    }
}

#Preview {
    RemoveResourceView(
        title: "Remove email address",
        messageLine1: "ClerkUser@clerk.dev will be removed from this account.",
        messageLine2: "You will no longer be able to sign in using this email address."
    )
    .onDelete {
        print("DELETED")
    }
}
