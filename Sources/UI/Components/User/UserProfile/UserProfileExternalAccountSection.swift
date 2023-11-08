//
//  UserProfileExternalAccountSection.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI

struct UserProfileExternalAccountSection: View {
    @EnvironmentObject private var clerk: Clerk
    @Environment(\.clerkTheme) private var clerkTheme
    
    private var user: User? {
        clerk.client.lastActiveSession?.user
    }
    
    private var externalAccounts: [ExternalAccount] {
        user?.externalAccounts ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserProfileSectionHeader(title: "Connected accounts")
            VStack(alignment: .leading, spacing: 24) {
                ForEach(externalAccounts) { externalAccount in
                    AccordionView {
                        HStack(spacing: 8) {
                            if let provider = externalAccount.externalProvider {
                                LazyImage(url: provider.iconImageUrl)
                                    .frame(width: 16, height: 16)
                                Text(provider.data.name) + Text(verbatim: " (\(externalAccount.displayName))")
                            }
                        }
                        .font(.footnote.weight(.medium))
                    } expandedContent: {
                        VStack(alignment: .leading) {
                            Text("Remove")
                                .font(.footnote.weight(.medium))
                            Text("Remove this connected account from your account")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Remove connected account", role: .destructive) {
                                // delete connected account
                            }
                            .font(.footnote)
                            .padding(.vertical, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    }
                }
                
                Button(action: {
                    // add email address
                }, label: {
                    Text("+ Connect account")
                })
                .font(.footnote.weight(.medium))
                .tint(clerkTheme.colors.primary)
                .padding(.leading, 8)
            }
        }
    }
}

#Preview {
    UserProfileExternalAccountSection()
        .padding()
        .environmentObject(Clerk.mock)
}

#endif
