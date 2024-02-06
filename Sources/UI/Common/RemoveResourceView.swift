//
//  RemoveResourceView.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

import SwiftUI
import ClerkSDK

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
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkSecondaryButtonStyle())
                
                AsyncButton {
                    await onDelete?()
                } label: {
                    Text("Remove")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkDangerButtonStyle())
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
