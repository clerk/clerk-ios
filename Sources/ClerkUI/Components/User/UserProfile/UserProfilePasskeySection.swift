//
//  UserProfilePasskeySection.swift
//
//
//  Created by Mike Pitre on 9/6/24.
//

#if os(iOS)

import SwiftUI
import Clerk
import AuthenticationServices

struct UserProfilePasskeySection: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkTheme.self) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    
    private var user: User? {
        clerk.client?.lastActiveSession?.user
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Passkeys")
                .font(.footnote.weight(.medium))
            
            if let user, !user.passkeys.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(user.passkeys) { passkey in
                        UserProfilePasskeyView(passkey: passkey)
                    }
                }
                .padding(.leading, 12)
            }
            
            AsyncButton(action: {
                await createPasskey()
            }, label: {
                Text("+ Add a passkey")
                    .font(.caption.weight(.medium))
                    .frame(minHeight: 32)
                    .tint(clerkTheme.colors.textPrimary)
            })
            .padding(.leading, 12)
            
            Divider()
        }
        .clerkErrorPresenting($errorWrapper)
        .animation(.snappy, value: user?.passkeys)
    }
}

extension UserProfilePasskeySection {
    
    @MainActor
    func createPasskey() async {
        guard let user else { return }
        
        do {
            try await user.createPasskey()
        } catch {
            if error.isCancelledError { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
}

#Preview {
    UserProfilePasskeySection()
}

#endif
